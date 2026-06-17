# Unit used when comparing product quantities across variants.
class ComparisonUnit < ApplicationRecord
  has_many :product_variants, inverse_of: :comparison_unit, dependent: :restrict_with_exception
  has_many :price_observations, inverse_of: :comparison_unit, dependent: :restrict_with_exception

  validates :name, :symbol, :normalized_name, :slug, presence: true
  validates :normalized_name, :slug, :symbol, uniqueness: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at id name normalized_name slug symbol updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[price_observations product_variants]
  end
end
