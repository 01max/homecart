# Product-facing brand identity, optionally linked to a retailer private label.
class ProductBrand < ApplicationRecord
  belongs_to :retail_brand, inverse_of: :product_brands, optional: true

  has_many :products, inverse_of: :product_brand, dependent: :restrict_with_exception

  validates :name, :normalized_name, :slug, presence: true
  validates :normalized_name, :slug, uniqueness: true
end
