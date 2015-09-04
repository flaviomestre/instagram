class AddInstagramMediaLink < ActiveRecord::Migration
  def connection
    InstagramDatabase.connection
  end

  def up
    add_column :instagram_media, :link, :string
  end
end
