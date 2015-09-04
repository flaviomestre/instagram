namespace :instagram do
  desc "Update user stats from instagram"
  task update_user_stats: :environment do
    username = ENV['username'] or raise "No username specified"
    client = InstagramService.new
    results = client.user_search(username)
    user_id = results.first.id
    user = client.user(user_id)
    saved_user = InstagramUser.save_user(user)
    unless saved_user.profile_id
      profile = Profile.find_or_initialize_by handle: username
      if profile.new_record?
        profile.update!(
          name: saved_user.full_name,
          bio: saved_user.bio,
        )
      end
      saved_user.update!(profile_id: profile.id)
    end
    saved_user.update_media
    saved_user.update_follows
    saved_user.update_followers
  end

  task compute_users_genders: :environment do
    require "i18n"
    InstagramUser.where(gender: nil).find_each do |u|
      full_name = I18n.transliterate(u.full_name).gsub(/[^a-z]/i, ' ').strip
      next if full_name.empty?
      first_name = full_name.split.first.downcase
      name = Name.find_by name: first_name
      if name
        u.update!(gender: name.gender)
      else
        puts first_name
      end
    end
  end

  task compute_users_locations: :environment do
    require 'ruby-progressbar'
    total = InstagramUser.where(last_known_latitude: nil, is_private: false).count
    bar = ProgressBar.create(
      title: "Computing locations",
      total: total,
      format: "%t: %c |%B| %C %E"
    )
    InstagramUser.where(last_known_latitude: nil, is_private: false).find_each do |u|
      bar.increment if bar.progress < bar.total
      u.update_location
    end
  end

  task update_users_recent_media: :environment do
    InstagramUser.where.not(profile_id: nil).find_each do |u|
      u.update_user
      u.update_recent_media
    end
  end

  task update_users_relationships: :environment do
    InstagramUser.where.not(profile_id: nil).find_each do |u|
      u.update_follows
      u.update_followers
    end
  end
end
