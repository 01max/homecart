# Concrete purchasable product form observed or matched from receipts.
class ProductVariant < ApplicationRecord
  belongs_to :comparison_unit, inverse_of: :product_variants, optional: true
  belongs_to :product, inverse_of: :product_variants

  has_many :product_alternative_group_memberships,
           inverse_of: :product_variant,
           dependent: :restrict_with_exception
  has_many :product_alternative_groups, through: :product_alternative_group_memberships
  has_many :receipt_line_matches, inverse_of: :product_variant, dependent: :restrict_with_exception
  has_many :price_observations, inverse_of: :product_variant, dependent: :restrict_with_exception

  validates :name, :normalized_name, :slug, presence: true
  validates :barcode, uniqueness: true, allow_nil: true
  validates :normalized_name, uniqueness: { scope: :product_id }
  validates :package_count, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :quantity_value, numericality: { greater_than: 0 }, allow_nil: true
  validates :slug, uniqueness: { scope: :product_id }
end
