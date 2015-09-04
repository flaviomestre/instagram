class AddInstagramLocation < ActiveRecord::Migration
  def connection
    InstagramDatabase.connection
  end

  def up
    add_column :instagram_users, :last_known_location_name, :string
  end
end
