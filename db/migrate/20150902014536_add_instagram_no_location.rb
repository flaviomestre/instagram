class AddInstagramNoLocation < ActiveRecord::Migration
  def connection
    InstagramDatabase.connection
  end

  def up
    add_column :instagram_users, :unknown_location_until, :datetime
  end
end
