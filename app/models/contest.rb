class Contest < ActiveRecord::Base
  xss_foliate :scrub => [:raw_post]
  has_many :posts, :order => "published_at desc"

  validates_presence_of :begin_date, :end_date, :title, :banner_title, :banner_subtitle
  
  scope :active, :conditions => ["begin_date < ? AND end_date > ?", Time.now, Time.now], :order => 'created_at desc'

  def self.current
    active.find(:first)
  end

  def self.get_active
    Contest.find(:first, :conditions => ["begin_date < ? AND end_date > ?", Time.now, Time.now], :order => 'created_at desc')
  end
  
  def active?
    (self.begin_date < Time.now ) and (self.end_date > Time.now )
  end

  def time_and_date
    if spans_days?
      string = "#{start_time.strftime("%B %d")} to #{end_time.strftime("%B %d %Y")}"
    else
      string = "#{start_time.strftime("%B %d, %Y")}, #{start_time.strftime("%I:%M %p")} - #{end_time.strftime("%I:%M %p")}"
    end
  end

  def spans_days?
    (end_time - start_time) >= 86400
  end
  
  def start_time
    self.begin_date
  end
  
  def end_time
    self.end_date
  end

  
end
