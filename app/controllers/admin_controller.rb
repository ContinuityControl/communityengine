class AdminController < BaseController
  before_filter :admin_required
  
  def contests
    @contests = Contest.find(:all)

    respond_to do |format|
      format.html # index.rhtml
      format.xml  { render :xml => @contests.to_xml }
    end    
  end

  def events
    @events = Event.paginate(:order => 'start_time DESC', :page => params[:page])
  end
  
  def messages
    @user = current_user
    @messages = Message.paginate(:page => params[:page], :per_page => 50, :order => 'created_at DESC')
  end
  
  def users
    @users = User.recent
    user = User.arel_table

    if params['login']    
      @users = @users.where('`users`.login LIKE ?', "%#{params['login']}%")
    end
    if params['email']
      @users = @users.where('`users`.email LIKE ?', "%#{params['email']}%")
    end        
    
    @users = @users.paginate(:page => params[:page], :per_page => 100)
  end
  
  def comments
    @search = Comment.search(params[:search])
    @search.order ||= :descend_by_created_at        
    @comments = @search.paginate(:page => params[:page], :per_page => 100)
  end
  
  def activate_user
    user = User.find(params[:id])
    user.activate
    flash[:notice] = :the_user_was_activated.l
    redirect_to :action => :users
  end
  
  def deactivate_user
    user = User.find(params[:id])
    user.deactivate
    flash[:notice] = :the_user_was_deactivated.l
    redirect_to :action => :users
  end  
  
end
