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

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      barcode comparison_unit_id created_at id name normalized_name package_count product_id quantity_value slug updated_at
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[
      comparison_unit price_observations product product_alternative_group_memberships product_alternative_groups
      receipt_line_matches
    ]
  end
end

# == Schema Information
#
# Table name: product_variants
#
#  id                 :uuid             not null, primary key
#  product_id         :uuid             not null, indexed, indexed => [normalized_name], indexed => [slug]
#  name               :string           not null
#  normalized_name    :string           not null, indexed, indexed => [product_id]
#  slug               :string           not null, indexed => [product_id]
#  package_count      :integer
#  quantity_value     :decimal(10, 3)
#  comparison_unit_id :uuid             indexed
#  barcode            :string           indexed
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_product_variants_on_barcode                         (barcode) UNIQUE
#  index_product_variants_on_comparison_unit_id              (comparison_unit_id)
#  index_product_variants_on_normalized_name_trgm            (normalized_name)
#  index_product_variants_on_product_id                      (product_id)
#  index_product_variants_on_product_id_and_normalized_name  (product_id,normalized_name) UNIQUE
#  index_product_variants_on_product_id_and_slug             (product_id,slug) UNIQUE
#
