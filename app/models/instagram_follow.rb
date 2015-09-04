class InstagramFollow < InstagramDatabase
  belongs_to :followed, :class_name => 'InstagramUser'
  belongs_to :follower, :class_name => 'InstagramUser'

  validates :followed_id, uniqueness: {scope: :follower_id}
end
