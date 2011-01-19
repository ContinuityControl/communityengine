module FriendshipsHelper

  def friendship_control_links(friendship)
    case friendship.friendship_status_id
      when FriendshipStatus[:pending].id
        "#{(link_to(content_tag(:span, accept.l), accept_user_friendship_path(friendship.user, friendship), :method => :put, :class => 'button rect_button small_green_buttton') unless friendship.initiator?)} #{link_to(:deny.l, deny_user_friendship_path(friendship.user, friendship), :method => :put, :class => 'button negative')}".html_safe
      when FriendshipStatus[:accepted].id
        "#{link_to(content_tag(:span, :remove_this_friend.l), deny_user_friendship_path(friendship.user, friendship), :method => :put, :class => 'button rect_button')}".html_safe
      when FriendshipStatus[:denied].id
    		"#{link_to(content_tag(:span, accept_this_request.l), accept_user_friendship_path(friendship.user, friendship), :method => :put, :class => 'button rect_button small_green_button')}".html_safe
    end
  end

end
