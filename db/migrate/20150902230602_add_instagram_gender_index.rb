class AddInstagramGenderIndex < ActiveRecord::Migration
  def connection
    InstagramDatabase.connection
  end

  def up
    add_index :instagram_users, :gender
  end
end
