class InstagramDatabase < ActiveRecord::Base
  self.abstract_class = true
  establish_connection (Rails.env.production? ? ENV['INSTAGRAM_DATABASE_URL'] : "instagram_#{Rails.env}".to_sym)
end
