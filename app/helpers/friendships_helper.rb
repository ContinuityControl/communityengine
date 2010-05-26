module FriendshipsHelper

  def friendship_control_links(friendship)
    case friendship.friendship_status_id
      when FriendshipStatus[:pending].id
        "#{(link_to("<span>" + :accept.l + "</span>", accept_user_friendship_path(friendship.user, friendship), :method => :put, :class => 'button rect_button small_green_buttton') unless friendship.initiator?)} #{link_to(:deny.l, deny_user_friendship_path(friendship.user, friendship), :method => :put, :class => 'button negative')}"
      when FriendshipStatus[:accepted].id
        "#{link_to("<span>" + :remove_this_friend.l + "</span>", deny_user_friendship_path(friendship.user, friendship), :method => :put, :class => 'button rect_button')}"
      when FriendshipStatus[:denied].id
    		"#{link_to("<span>" + :accept_this_request.l + "</span>", accept_user_friendship_path(friendship.user, friendship), :method => :put, :class => 'button rect_button small_green_button')}"
    end
  end

end
