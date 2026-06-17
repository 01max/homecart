# Company responsible for manufacturing one or more products.
class Manufacturer < ApplicationRecord
  has_many :products, inverse_of: :manufacturer, dependent: :restrict_with_exception

  validates :name, :normalized_name, :slug, presence: true
  validates :normalized_name, :slug, uniqueness: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at id name normalized_name slug updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[products]
  end
end
