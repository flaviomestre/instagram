class InstagramUser < InstagramDatabase
  has_many :instagram_follows, class_name: 'InstagramFollow',
    foreign_key: 'follower_id', dependent: :destroy
  has_many :instagram_followers, class_name: 'InstagramFollow',
    foreign_key: 'followed_id', dependent: :destroy
  has_many :follows, through: :instagram_follows, source: :followed
  has_many :followers, through: :instagram_followers, source: :follower
  has_many :instagram_media, dependent: :destroy
  has_many :instagram_likes, dependent: :destroy
  has_many :instagram_comments, dependent: :destroy

  validates :instagram_id, uniqueness: true
  #validates :gender, inclusion: {in: ['male', 'female']}

  def self.save_user(user)
    saved_user = find_or_initialize_by(instagram_id: user.id)
    saved_user.save_user(user)
    saved_user
  end

  # All distances here are in meters
  def self.close_to(latitude, longitude, max_distance: 2000)
    one_degree_of_latitude = 111200.0
    one_degree_of_longitude = (Math.cos(latitude*Math::PI/180)*one_degree_of_latitude).abs
    latitude_delta = max_distance / one_degree_of_latitude
    longitude_delta = max_distance / one_degree_of_longitude
    in_box = where(
      last_known_latitude: (latitude-latitude_delta)..(latitude+latitude_delta),
      last_known_longitude: (longitude-longitude_delta)..(longitude+longitude_delta)
    )
    earth_radius = 6371000.0
    distances = {}
    in_box.find_each do |u|
      a = Math.sin((latitude-u.last_known_latitude) * Math::PI/180 / 2)
      b = Math.sin((longitude-u.last_known_longitude) * Math::PI/180 / 2)
      c = Math.cos(latitude * Math::PI/180) * Math.cos(u.last_known_latitude * Math::PI/180)
      d = earth_radius*2 * Math.asin(Math.sqrt(a*a + c*b*b))
      distances[u] = d if d <= max_distance
    end
    distances.sort
  end

  def profile
    Profile.find_by id: profile_id
  end

  def save_user(user)
    self.bio = user.bio if user.bio
    if user.counts
      self.followers_count = user.counts.followed_by
      self.follows_count = user.counts.follows
      self.media_count = user.counts.media
    end
    self.username = user.username
    self.full_name = user.full_name
    self.avatar = user.profile_picture
    save!
  end

  def save_medium(medium)
    saved_medium = instagram_media.find_or_initialize_by instagram_id: medium.id
    data = medium.send("#{medium.type}s").standard_resolution
    saved_medium.update!({
      created_time: Time.at(medium.created_time.to_i),
      type: medium.type,
      url: data.url,
      width: data.width,
      height: data.height,
      likes_count: medium.likes['count'],
      comments_count: medium.comments['count'],
      tags: medium.tags.sort,
      link: medium.link
    })
    save_comment(medium.caption, saved_medium) if medium.caption
    saved_medium.update_likes
    saved_medium.update_comments
    saved_medium
  end

  def save_comment(comment, saved_medium)
    saved_comment = instagram_comments.find_or_initialize_by(instagram_id: comment.id,
      instagram_medium_id: saved_medium.id)
    saved_comment.update!({
      created_time: Time.at(comment.created_time.to_i),
      text: comment.text,
    })
    saved_comment
  end

  def follow(other_user)
    instagram_follows.create(followed_id: other_user.id)
  end

  def unfollow(other_user)
    instagram_follows.find_by(followed_id: other_user.id).destroy
  end

  def following?(other_user)
    instagram_follows.find_by(followed_id: other_user.id).present?
  end

  def like(medium)
    instagram_likes.create(instagram_medium_id: medium.id)
  end

  def unlike(medium)
    instagram_likes.find_by(instagram_medium_id: medium.id).destroy
  end

  def likes?(medium)
    instagram_likes.find_by(instagram_medium_id: medium.id).present?
  end

  def media_having_tag(tag)
    instagram_media.where("tags @> ?", "{#{tag}}")
  end

  def most_liked_tags(quantity=10)
    Rails.cache.fetch("#{cache_key}/most_liked_tags/#{quantity}", expires_in: 12.hours) do
      likes = {}
      instagram_media.find_each do |m|
        if m.tags && m.likes_count
          m.tags.each do |t|
            likes[t] = likes.fetch(t,0) + m.likes_count
          end
        end
      end
      likes.sort_by{|k,v|-v}.take(quantity)
    end
  end

  def most_commented_tags(quantity=10)
    Rails.cache.fetch("#{cache_key}/most_commented_tags/#{quantity}", expires_in: 12.hours) do
      comments = {}
      instagram_media.find_each do |m|
        if m.tags && m.comments_count
          m.tags.each do |t|
            comments[t] = comments.fetch(t,0) + m.comments_count
          end
        end
      end
      comments.sort_by{|k,v|-v}.take(quantity)
    end
  end

  def update_user
    user = client.user(instagram_id)
    save_user(user)
  end

  def update_followers
    require 'ruby-progressbar'
    status = Rails.cache.fetch("#{cache_key}/update_followers") || [nil, nil]
    cursor = status.first
    progress = status.second
    bar = ProgressBar.create(
      title: "Updating followers of #{username}",
      starting_at: progress,
      total: followers_count,
      format: "%t: %c |%B| %C %E"
    )
    loop do
      followers = client.user_followed_by(instagram_id, {cursor: cursor, count: 100})
      followers.each do |f|
        bar.increment if bar.progress < bar.total
        saved_follower = self.class.save_user(f)
        saved_follower.follow(self) unless saved_follower.following?(self)
      end
      cursor = followers.pagination[:next_cursor]
      break if cursor.to_s.empty?
      Rails.cache.write("#{cache_key}/update_followers", [cursor, bar.progress], expires_in: 12.hours)
    end
  end

  def update_follows
    require 'ruby-progressbar'
    status = Rails.cache.fetch("#{cache_key}/update_follows") || [nil, nil]
    cursor = status.first
    progress = status.second
    bar = ProgressBar.create(
      title: "Updating follows of #{username}",
      starting_at: progress,
      total: follows_count,
      format: "%t: %c |%B| %C %E"
    )
    loop do
      users = client.user_follows(instagram_id, {cursor: cursor, count: 100})
      users.each do |u|
        bar.increment if bar.progress < bar.total
        saved_user = self.class.find_or_initialize_by(instagram_id: u.id)
        begin
          saved_user.update_user unless saved_user.is_private
        rescue Instagram::BadRequest => e
          saved_user.is_private = true
        end
        saved_user.save_user(u) if saved_user.is_private
        follow(saved_user) unless following?(saved_user)
      end
      cursor = users.pagination[:next_cursor]
      break if cursor.to_s.empty?
      Rails.cache.write("#{cache_key}/update_follows", [cursor, bar.progress], expires_in: 12.hours)
    end
  end

  def update_media
    require 'ruby-progressbar'
    status = Rails.cache.fetch("#{cache_key}/update_media") || [nil, nil]
    max_id = status.first
    progress = status.second
    bar = ProgressBar.create(
      title: "Updating media of #{username}",
      starting_at: progress,
      total: media_count,
      format: "%t: %c |%B| %C %E"
    )
    loop do
      media = client.user_recent_media(instagram_id, {max_id: max_id, count: 33})
      media.each do |m|
        bar.increment if bar.progress < bar.total
        save_medium(m)
      end
      max_id = media.pagination[:next_max_id]
      break if max_id.nil?
      Rails.cache.write("#{cache_key}/update_media", [max_id, bar.progress], expires_in: 12.hours)
    end
  end

  def update_recent_media
    require 'ruby-progressbar'
    media = client.user_recent_media(instagram_id, {count: 10})
    bar = ProgressBar.create(
      title: "Updating recent media of #{username}",
      total: media.count,
      format: "%t: %c |%B| %C %E"
    )
    media.each do |m|
      bar.increment
      save_medium(m)
    end
  end

  def update_location
    max_id = nil
    loop do
      media = client.user_recent_media(instagram_id, {max_id: max_id, count: 33})
      media.each do |m|
        if unknown_location_until && unknown_location_until >= Time.at(m.created_time.to_i)
          return update!(unknown_location_until: Time.current)
        end
        if m.location && m.location.latitude
          return update!(
            last_known_latitude: m.location.latitude,
            last_known_longitude: m.location.longitude,
            last_known_location_name: m.location.name)
        end
      end
      max_id = media.pagination[:next_max_id]
      break if max_id.nil?
    end
    update!(unknown_location_until: Time.current)
  rescue Instagram::BadRequest => e
    update!(is_private: true)
  end

  private

    def client
      @client ||= InstagramService.new
    end
end
