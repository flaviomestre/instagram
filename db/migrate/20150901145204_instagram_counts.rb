class InstagramCounts < ActiveRecord::Migration
  def connection
    InstagramDatabase.connection
  end

  def up
    add_column :instagram_media, :likes_count, :integer
    add_column :instagram_media, :comments_count, :integer
  end
end
