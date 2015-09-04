class InstagramComment < InstagramDatabase
  validates :instagram_id, uniqueness: true
end
