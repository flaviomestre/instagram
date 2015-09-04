class InstagramStats < ActiveRecord::Migration
  def connection
    InstagramDatabase.connection
  end

  # Can't use "change" because of custom connection
  def up
    create_table :instagram_users do |t|
      t.references :profile, index: true
      t.bigint :instagram_id, index: true
      t.string :username
      t.string :full_name
      t.string :avatar
      t.string :gender
      t.integer :followers_count
      t.decimal :last_known_latitude, precision: 9, scale: 6
      t.decimal :last_known_longitude, precision: 9, scale: 6
      t.text :bio
    end

    create_table :instagram_follows do |t|
      t.references :followed, references: :instagram_user, index: true
      t.references :follower, references: :instagram_user, index: true
    end

    create_table :instagram_media do |t|
      t.references :instagram_user, index: true
      t.string :instagram_id, index: true
      t.datetime :created_time
      t.string :type
      t.string :url
      t.integer :width
      t.integer :height
    end

    create_table :instagram_comments do |t|
      t.references :instagram_medium, index: true
      t.references :instagram_user, index: true
      t.bigint :instagram_id, index: true
      t.datetime :created_time
      t.text :text
    end

    create_table :instagram_likes do |t|
      t.references :instagram_medium, index: true
      t.references :instagram_user, index: true
    end

    create_table :instagram_tags do |t|
      t.references :instagram_user, index: true
      t.string :name
      t.integer :uses
      t.integer :likes
    end
  end
end
