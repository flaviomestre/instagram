class MoreInstagramCounts < ActiveRecord::Migration
  def connection
    InstagramDatabase.connection
  end

  def up
    add_column :instagram_users, :follows_count, :integer
    add_column :instagram_users, :media_count, :integer
  end
end
