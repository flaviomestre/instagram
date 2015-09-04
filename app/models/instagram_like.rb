class InstagramLike < InstagramDatabase
  belongs_to :instagram_user
  belongs_to :instagram_medium

  validates :instagram_user_id, uniqueness: {scope: :instagram_medium_id}
end
