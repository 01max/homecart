# Company responsible for manufacturing one or more products.
class Manufacturer < ApplicationRecord
  has_many :products, inverse_of: :manufacturer, dependent: :restrict_with_exception

  validates :name, :normalized_name, :slug, presence: true
  validates :normalized_name, :slug, uniqueness: true
end
