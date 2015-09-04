class InstagramMedium < InstagramDatabase
  belongs_to :instagram_user
  has_many :instagram_likes, dependent: :destroy
  has_many :instagram_comments, dependent: :destroy

  # Needed because of "type" column
  self.inheritance_column = :_type_disabled

  validates :instagram_id, uniqueness: true
  validates :type, inclusion: {in: ['video', 'image']}

  def update_likes
    likes = client.media_likes(instagram_id)
    likes.each do |l|
      user = InstagramUser.save_user(l)
      user.like(self) unless user.likes?(self)
    end
  end

  def update_comments
    comments = client.media_comments(instagram_id)
    comments.each do |c|
      user = InstagramUser.save_user(c.from)
      user.save_comment(c, self)
    end
  end

  def oembed(*args)
    url = args.first
    return nil unless url
    Instagram.get("/publicapi/oembed?url=#{url}", {}, false, false, true)
  end

  def image(size = 'm')
    self.link.concat("media/?size=#{size}")
  end

  private

    def client
      @client ||= InstagramService.new
    end
end
