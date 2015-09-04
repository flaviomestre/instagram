class InstagramTags < ActiveRecord::Migration
  def connection
    InstagramDatabase.connection
  end

  def up
    drop_table :instagram_tags
    add_column :instagram_media, :tags, :text, array: true
    add_index :instagram_media, :tags, using: 'gin'
  end
end
