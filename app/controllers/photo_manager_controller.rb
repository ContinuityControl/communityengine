class PhotoManagerController < BaseController
  include Viewable
  before_filter :login_required
  before_filter :find_user
  before_filter :require_current_user
  
  def index
    @albums = Album.paginate(:conditions => ['user_id = ?', current_user], :order => 'id DESC',
      :page => params[:page_albums], :per_page => 10 )
    @photos_no_albums = Photo.paginate( :page => params[:page], :per_page => 10,
     :conditions => ['album_id IS NULL AND parent_id IS NULL AND user_id = ?', current_user],
     :order => 'id DESC')
  end
end
