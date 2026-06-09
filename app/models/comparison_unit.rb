# Unit used when comparing product quantities across variants.
class ComparisonUnit < ApplicationRecord
  has_many :product_variants, inverse_of: :comparison_unit, dependent: :restrict_with_exception

  validates :name, :symbol, :normalized_name, :slug, presence: true
  validates :normalized_name, :slug, :symbol, uniqueness: true
end
