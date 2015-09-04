class AddInstagramLocationIndex < ActiveRecord::Migration
  def connection
    InstagramDatabase.connection
  end

  def up
    add_index :instagram_users, :last_known_latitude
    add_index :instagram_users, :last_known_longitude
  end
end
