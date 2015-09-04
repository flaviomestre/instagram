class AddInstagramUserPrivacy < ActiveRecord::Migration
  def connection
    InstagramDatabase.connection
  end

  def up
    add_column :instagram_users, :is_private, :boolean, null: false, default: false
  end
end
