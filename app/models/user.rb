require 'digest/sha1'

class User < ActiveRecord::Base
  xss_foliate :strip => [:raw_post, :title]
  has_friendly_id :login_slug
  has_many :albums
  
  MALE    = 'M'
  FEMALE  = 'F'
  #attr_protected :admin, :featured, :role_id
  
  attr_accessible :avatar_id, :company_name, :country_id, :description, :email,
    :firstname, :fullname, :gender, :lastname, :login, :metro_area_id,
    :middlename, :notify_comments, :notify_community_news,
    :notify_friend_requests, :password, :password_confirmation,
    :profile_public, :state_id, :stylesheet, :time_zone, :vendor, :zip

  acts_as_taggable  
  acts_as_commentable
  has_private_messages
  tracks_unlinked_activities [:logged_in, :invited_friends, :updated_profile, :joined_the_site]  
  
  #callbacks  
  before_save   :whitelist_attributes
  before_create :make_activation_code, :if => Proc.new { |user| user.activated_at.nil? && user.activation_code.nil? }
  after_create  :update_last_login
  after_create  :deliver_signup_notification
  after_save    :deliver_activation, :if => Proc.new { |user| user.recently_activated? }
  before_validation   :generate_login_slug
  after_save    :recount_metro_area_users
  after_destroy :recount_metro_area_users


  #validation
  validates_presence_of     :metro_area,                 :if => Proc.new { |user| user.state }
  validates_uniqueness_of   :login_slug
  validates_exclusion_of    :login, :in => AppConfig.reserved_logins
  validates_date :birthday, :before => 13.years.ago.to_date  

  #associations
    has_enumerated :role  
    has_many :posts, :order => "published_at desc", :dependent => :destroy
    has_many :photos, :order => "created_at desc", :dependent => :destroy
    has_many :invitations, :dependent => :destroy
    has_many :offerings, :dependent => :destroy
    has_many :rsvps, :dependent => :destroy

    #friendship associations
    has_many :friendships, :class_name => "Friendship", :foreign_key => "user_id", :dependent => :destroy
    has_many :accepted_friendships, :class_name => "Friendship", :conditions => ['friendship_status_id = ?', 2]
    has_many :pending_friendships, :class_name => "Friendship", :conditions => ['initiator = ? AND friendship_status_id = ?', false, 1]
    has_many :friendships_initiated_by_me, :class_name => "Friendship", :foreign_key => "user_id", :conditions => ['initiator = ?', true], :dependent => :destroy
    has_many :friendships_not_initiated_by_me, :class_name => "Friendship", :foreign_key => "user_id", :conditions => ['initiator = ?', false], :dependent => :destroy
    has_many :occurances_as_friend, :class_name => "Friendship", :foreign_key => "friend_id", :dependent => :destroy

    #forums
    has_many :moderatorships, :dependent => :destroy
    has_many :forums, :through => :moderatorships, :order => 'forums.name'
    has_many :sb_posts, :dependent => :destroy
    has_many :topics, :dependent => :destroy
    has_many :monitorships, :dependent => :destroy
    has_many :monitored_topics, :through => :monitorships, :conditions => ['monitorships.active = ?', true], :order => 'topics.replied_at desc', :source => :topic

    belongs_to  :avatar, :class_name => "Photo", :foreign_key => "avatar_id"
    belongs_to  :metro_area
    belongs_to  :state
    belongs_to  :country
    has_many    :comments_as_author, :class_name => "Comment", :foreign_key => "user_id", :order => "created_at desc", :dependent => :destroy
    has_many    :comments_as_recipient, :class_name => "Comment", :foreign_key => "recipient_id", :order => "created_at desc", :dependent => :destroy
    has_many    :clippings, :order => "created_at desc", :dependent => :destroy
    has_many    :favorites, :order => "created_at desc", :dependent => :destroy
    
  #named scopes
  scope :recent, :order => 'users.created_at DESC'
  scope :featured, :conditions => ["users.featured_writer = ?", true]
  scope :active, :conditions => ["users.activated_at IS NOT NULL"]  
  scope :vendors, :conditions => ["users.vendor = ?", true]
  scope :tagged_with, lambda {|tag_name|
    {:conditions => ["tags.name = ?", tag_name], :include => :tags}
  }
  

  ## Class Methods

  def self.find_country_and_state_from_search_params(search)
    country     = Country.find(search['country_id']) if !search['country_id'].blank?
    state       = State.find(search['state_id']) if !search['state_id'].blank?
    metro_area  = MetroArea.find(search['metro_area_id']) if !search['metro_area_id'].blank?

    if metro_area && metro_area.country
      country ||= metro_area.country 
      state   ||= metro_area.state
      search['country_id'] = metro_area.country.id if metro_area.country
      search['state_id'] = metro_area.state.id if metro_area.state      
    end
    
    states  = country ? country.states.sort_by{|s| s.name} : []
    if states.any?
      metro_areas = state ? state.metro_areas.all(:order => "name") : []
    else
      metro_areas = country ? country.metro_areas : []
    end    
    
    return [metro_areas, states]
  end

  def self.prepare_params_for_search(params)
    search = {}.merge(params)
    search['metro_area_id'] = params[:metro_area_id] || nil
    search['state_id'] = params[:state_id] || nil
    search['country_id'] = params[:country_id] || nil
    search['skill_id'] = params[:skill_id] || nil    
    search
  end
  
  def self.build_conditions_for_search(search)
    user = User.arel_table
    users = User.where(user[:activated_at].not_eq nil)
    if search['country_id'] && !(search['metro_area_id'] || search['state_id'])
      users = users.where(user[:country_id].eq search['country_id'])
    end
    if search['state_id'] && !search['metro_area_id']
      users = users.where(user[:state_id].eq search['state_id'])
    end
    if search['metro_area_id']
      users = users.where(user[:metro_area_id].eq search['metro_area_id'])
    end
    if search['login']    
      users = users.where('`users`.login LIKE ?', "%#{search['login']}%")
    end
    if search['vendor']
      users = users.where(user[:vendor].eq true)
    end    
    if search['description']
      users = users.where('`users`.description LIKE ?', "%#{search['description']}%")
    end    
    users
  end  
  
  def self.find_by_activity(options = {})
    options.reverse_merge! :limit => 30, :require_avatar => true, :since => 7.days.ago   

    activities = Activity.since(options[:since]).find(:all, 
      :select => 'activities.user_id, count(*) as count', 
      :group => 'activities.user_id', 
      :conditions => "#{options[:require_avatar] ? ' users.avatar_id IS NOT NULL AND ' : ''} users.activated_at IS NOT NULL", 
      :order => 'count DESC', 
      :joins => "LEFT JOIN users ON users.id = activities.user_id",
      :limit => options[:limit]
      )
    activities.map{|a| find(a.user_id) }
  end  
    
  def self.find_featured
    self.featured
  end
  
  def self.paginated_users_conditions_with_search(params)
    search = prepare_params_for_search(params)

    metro_areas, states = find_country_and_state_from_search_params(search)
    
    users = build_conditions_for_search(search)
    return users, search, metro_areas, states
  end  

  
  def self.recent_activity(options = {})
    options.reverse_merge! :per_page => 10, :page => 1
    Activity.recent.paginate(
      :select => 'activities.*', 
      :conditions => "users.activated_at IS NOT NULL", 
      :joins => "LEFT JOIN users ON users.id = activities.user_id",
      *options)    
  end

  def self.currently_online
    User.find(:all, :conditions => ["sb_last_seen_at > ?", Time.now.utc-5.minutes])
  end
  
  def self.search(query, options = {})
    with_scope :find => { :conditions => build_search_conditions(query) } do
      find :all, options
    end
  end
  
  def self.build_search_conditions(query)
    query
  end  
  
  ## End Class Methods  
  
  
  ## Instance Methods
  
  def moderator_of?(forum)
    moderatorships.count(:all, :conditions => ['forum_id = ?', (forum.is_a?(Forum) ? forum.id : forum)]) == 1
  end
  
  def monitoring_topic?(topic)
    monitored_topics.find_by_id(topic.id)
  end

  def to_xml(options = {})
    options[:except] ||= []
    super
  end

  def recount_metro_area_users
    return unless self.metro_area
    ma = self.metro_area
    ma.users_count = User.count(:conditions => ["metro_area_id = ?", ma.id])
    ma.save
  end  
  
  def to_param
    login_slug
  end
  
  def this_months_posts
    self.posts.find(:all, :conditions => ["published_at > ?", DateTime.now.to_time.at_beginning_of_month])
  end
  
  def last_months_posts
    self.posts.find(:all, :conditions => ["published_at > ? and published_at < ?", DateTime.now.to_time.at_beginning_of_month.months_ago(1), DateTime.now.to_time.at_beginning_of_month])
  end
  
  def avatar_photo_url(size = nil)
    if avatar
      avatar.public_filename(size)
    else
      case size
        when :thumb
          AppConfig.photo['missing_thumb']
        else
          AppConfig.photo['missing_medium']
      end
    end
  end

  def deactivate
    return if admin? #don't allow admin deactivation
    @activated = false
    User.transaction do
      update_attribute(:activated_at, nil)
      update_attribute(:activation_code, make_activation_code)
    end
  end

  def activate
    @activated = true
    User.transaction do
      update_attribute(:activated_at, Time.now.utc)
      update_attribute(:activation_code, nil)
    end
  end
  
  def active?
    activation_code.nil? && !activated_at.nil?
  end

  def recently_activated?
    @activated
  end
  
  def valid_invite_code?(code)
    code == invite_code
  end
  
  def invite_code
    Digest::SHA1.hexdigest("#{self.id}--#{self.email}--#{self.password_salt}")
  end
  
  def location
    metro_area && metro_area.name || ""
  end
  
  def full_location
    "#{metro_area.name if self.metro_area}#{" , #{self.country.name}" if self.country}"
  end
  
  def reset_password
     new_password = newpass(8)
     self.password = new_password
     self.password_confirmation = new_password
     return self.valid?
  end

  def newpass( len )
     chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
     new_password = ""
     1.upto(len) { |i| new_password << chars[rand(chars.size-1)] }
     return new_password
  end
  
  def owner
    self
  end

  def staff?
    featured_writer?
  end
  
  def can_request_friendship_with(user)
    !self.eql?(user) && !self.friendship_exists_with?(user)
  end

  def friendship_exists_with?(friend)
    Friendship.find(:first, :conditions => ["user_id = ? AND friend_id = ?", self.id, friend.id])
  end
  
  # before filter
  def generate_login_slug
    self.login_slug = self.login.parameterize
  end
  
  def deliver_activation
    UserNotifier.deliver_activation(self) if self.recently_activated?
  end
  
  def deliver_signup_notification
    UserNotifier.deliver_signup_notification(self)    
  end

  def update_last_login
    self.track_activity(:logged_in) if self.active? && self.last_login_at.nil? || (self.last_login_at && self.last_login_at < Time.now.beginning_of_day)
    self.update_attribute(:last_login_at, Time.now)
  end
  
  def add_offerings(skills)
    skills.each do |skill_id|
      offering = Offering.new(:skill_id => skill_id)
      offering.user = self
      if self.under_offering_limit? && !self.has_skill?(offering.skill)
        if offering.save
          self.offerings << offering
        end
      end
    end
  end  
  
  def under_offering_limit?
    self.offerings.size < 3
  end
  
  def has_skill?(skill)
    self.offerings.collect{|o| o.skill }.include?(skill)
  end

  def has_reached_daily_friend_request_limit?
    friendships_initiated_by_me.count(:conditions => ['created_at > ?', Time.now.beginning_of_day]) >= Friendship.daily_request_limit
  end

  def network_activity(page = {}, since = 1.week.ago)
    page.reverse_merge! :per_page => 10, :page => 1
    friend_ids = self.friends_ids
    metro_area_people_ids = self.metro_area ? self.metro_area.users.map(&:id) : []
    
    ids = ((friends_ids | metro_area_people_ids) - [self.id])[0..100] #don't pull TOO much activity for now
    
    Activity.recent.since(since).by_users(ids).paginate(page)          
  end

  def comments_activity(page = {}, since = 1.week.ago)
    page.reverse_merge :per_page => 10, :page => 1

    Activity.recent.since(since).paginate( 
      :conditions => ['comments.recipient_id = ? AND activities.user_id != ?', self.id, self.id], 
      :joins => "LEFT JOIN comments ON comments.id = activities.item_id AND activities.item_type = 'Comment'",
      *page)
  end

  def friends_ids
    return [] if accepted_friendships.empty?
    accepted_friendships.map{|fr| fr.friend_id }
  end
  
  def recommended_posts(since = 1.week.ago)
    return [] if tags.empty?
    rec_posts = Post.find_tagged_with(tags.map(&:name), 
      :conditions => ['posts.user_id != ? AND published_at > ?', self.id, since ],
      :order => 'published_at DESC',      
      :limit => 10
      )

    if rec_posts.empty?
      []
    else
      rec_posts.uniq
    end
  end
  
  def display_name
    login
  end
  
  def admin?
    role && role.eql?(Role[:admin])
  end

  def moderator?
    role && role.eql?(Role[:moderator])
  end

  def member?
    role && role.eql?(Role[:member])
  end
  
  def male?
    gender && gender.eql?(MALE)
  end
  
  def female
    gender && gender.eql?(FEMALE)    
  end

  def update_last_seen_at
    User.update_all ['sb_last_seen_at = ?', Time.now.utc], ['id = ?', self.id]
    self.sb_last_seen_at = Time.now.utc
  end

  def deliver_password_reset_instructions!  
    reset_perishable_token!
    UserNotifier.deliver_reset_password(self)
  end 
  
  ## End Instance Methods
  

  protected

    def make_activation_code
      self.activation_code = Digest::SHA1.hexdigest( Time.now.to_s.split(//).sort_by {rand}.join )
    end

    # before filters
    def whitelist_attributes
      self.login = self.login.strip
    end

    def password_required?
      crypted_password.blank? || !password.blank?
    end
  
end
