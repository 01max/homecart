# Catalog product grouping one or more concrete purchasable variants.
class Product < ApplicationRecord
  belongs_to :category, inverse_of: :products
  belongs_to :manufacturer, inverse_of: :products, optional: true
  belongs_to :product_brand, inverse_of: :products

  has_many :product_variants, inverse_of: :product, dependent: :restrict_with_exception

  validates :name, :normalized_name, :slug, presence: true
  validates :normalized_name, uniqueness: { scope: %i[product_brand_id category_id] }
  validates :slug, uniqueness: { scope: %i[product_brand_id category_id] }
end
