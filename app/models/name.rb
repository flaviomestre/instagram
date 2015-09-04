class Name < ActiveRecord::Base
  validates :name, uniqueness: true
  validates :confidence, inclusion: {in: 0..100}
  validates :gender, inclusion: {in: ['male', 'female']}
end
