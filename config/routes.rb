Control::Application.routes.draw do
  resources :users do
    member do
      get :dashboard 
      get :assume 
      put :toggle_moderator 
      put :toggle_featured 
      put :change_profile_photo 
      get :return_admin 
      get :edit_account 
      put :update_account 
      get :edit_pro_details 
      put :update_pro_details 
      get :forgot_password 
      post :forgot_password 
      get :signup_completed 
      get :invite 
      get :welcome_photo 
      get :welcome_about 
      get :welcome_stylesheet 
      get :welcome_invite 
      get :welcome_complete 
      get :statistics 
      put :deactivate 
      get :crop_profile_photo 
      put :crop_profile_photo 
      get :upload_profile_photo 
      put :upload_profile_photo 
    end

    resources :friendships do
      collection do
        get :pending
        get :denied
        get :accepted
      end
      member do
        put :deny
        put :accept
      end
    end

    resources :photos do
      collection do
        post :swfupload
        get :slideshow
      end
    end

    resources :posts do
      collection do
        get :manage
      end
      member do
        get :contest
        post :send_to_friend
        post :update_views
      end
    end

    resources :events
    resources :clippings

    resources :activities do
      collection do
        get :network
      end
    end

    resources :invitations

    resources :offerings do
      collection do
        put :replace
      end
    end

    resources :favorites, :as => 'user_favorites'

    resources :messages do
      collection do
        post :delete_selected
        get :auto_complete_for_username
      end
    end

    resources :comments
    resources :photo_manager, :only => [:index]

    resources :albums, :path => '/:user_id/photo_manager' do
      resources :photos do
        collection do
          post :swfupload
          get :slideshow
        end
      end
    end
  end

  match '/forums/recent' => 'sb_posts#index', :as => :recent_forum_posts
  resources :forums
  resources :sb_posts
  resources :monitorship

  resources :sb_posts, :as => 'all_sb_posts' do
    collection do
      get :monitored
      get :search
    end
  end

  resources :sb_posts, :as => "forum_sb_posts", :path => '/forums/:forum_id'

  resources :forums do
    resources :moderators

    resources :topics do
      resources :sb_posts
      resource :monitorship, :controller => :monitorships
    end
  end

  match '/forums' => 'forums#index', :as => :forum_home
  resources :topics

  if AppConfig.closed_beta_mode
    match '/' => 'base#teaser'
    match 'home' => 'base#site_index', :as => :home
  else
    match '/' => 'base#site_index', :as => :home
  end
  match '/' => 'base#site_index', :as => :application

  resources :pages, :as => 'admin_pages', :path => '/admin', :except => [:show] do
    member do
      get :preview
    end
  end
  match 'pages/:id' => 'pages#show', :as => :pages

  match '/admin/dashboard' => 'homepage_features#index', :as => :admin_dashboard
  match '/admin/users' => 'admin#users', :as => :admin_users
  match '/admin/messages' => 'admin#messages', :as => :admin_messages
  match '/admin/comments' => 'admin#comments', :as => :admin_comments
  match 'admin/tags/:action' => 'tags#manage', :as => :admin_tags
  match 'admin/events' => 'admin#events', :as => :admin_events

  match '/' => 'base#teaser', :as => :teaser
  match '/login' => 'sessions#new', :as => :login
  match '/signup' => 'users#new', :as => :signup
  match '/logout' => 'sessions#destroy', :as => :logout
  match '/signup/:inviter_id/:inviter_code' => 'users#new', :as => :signup_by_id

  resources :password_resets
  match '/forgot_password' => 'users#forgot_password', :as => :forgot_password
  match '/forgot_username' => 'users#forgot_username', :as => :forgot_username
  match '/resend_activation' => 'users#resend_activation', :as => :resend_activation

  match '/new_clipping' => 'clippings#new_clipping'
  match '/clippings' => 'clippings#site_index', :as => :site_clippings
  match '/clippings.rss' => 'clippings#site_index', :as => :rss_site_clippings, :format => 'rss'

  match '/featured' => 'posts#featured', :as => :featured
  match '/featured.rss' => 'posts#featured', :as => :featured_rss, :format => 'rss'
  match '/popular' => 'posts#popular', :as => :popular
  match '/popular.rss' => 'posts#popular', :as => :popular_rss, :format => 'rss'
  match '/recent' => 'posts#recent', :as => :recent
  match '/recent.rss' => 'posts#recent', :as => :recent_rss, :format => 'rss'
  match '/rss' => 'base#rss_site_index', :as => :rss_redirect
  match '/site_index.rss' => 'base#site_index', :as => :rss, :format => 'rss'

  match '/advertise' => 'base#advertise', :as => :advertise
  match '/css_help' => 'base#css_help', :as => :css_help
  match '/about' => 'base#about', :as => :about
  match '/faq' => 'base#faq', :as => :faq

  match '/account/edit' => 'users#edit_account', :as => :edit_account_from_email

  match '/friendships.xml' => 'friendships#index', :as => :friendships_xml, :format => 'xml'
  match '/friendships' => 'friendships#index', :as => :friendships

  match 'manage_photos' => 'photos#manage_photos', :as => :manage_photos
  match 'create_photo.js' => 'photos#create', :as => :create_photo, :format => 'js'

  resources :sessions
  resources :statistics do
    collection do
      get :activities_chart
      get :activities
    end
  end
  resources :tags
  match '/tags/:id/:type' => 'tags#show', :as => :show_tag_type
  match '/search/tags' => 'tags#show', :as => :search_tags

  resources :categories
  resources :skills
  resources :events do
    member do
      get :clone
    end
    collection do
      get :past
      get :ical
    end
    resources :rsvps, :except => [:index, :show]
  end

  resources :favorites, :path => '/:favoritable_type/:favoritable_id'
  resources :comments, :path => '/:commentable_type/:commentable_id'
  match 'comments/delete_selected' => 'comments#delete_selected', :as => :delete_selected_comments

  resources :homepage_features
  resources :metro_areas
  resources :ads
  resources :contests do
    collection do
      get :current
    end
  end
  resources :activities

  resources :votes
  resources :invitations

  match '/users/:user_id/posts/category/:category_name' => 'posts#index', :as => :users_posts_in_category, :category_name => :category_name

  match '/popular_rss' => 'base#popular', :as => :deprecated_popular_rss, :format => 'rss'
  match '/categories/:id;rss' => 'categories#show', :as => :deprecated_category_rss, :format => 'rss'
  match '/:user_id/posts;rss' => 'posts#index', :as => :deprecated_posts_rss, :format => 'rss'

  match '/:controller(/:action(/:id))'
end
