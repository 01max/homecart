# Product-facing brand identity, optionally linked to a retailer private label.
class ProductBrand < ApplicationRecord
  belongs_to :retail_brand, inverse_of: :product_brands, optional: true

  has_many :products, inverse_of: :product_brand, dependent: :restrict_with_exception

  validates :name, :normalized_name, :slug, presence: true
  validates :normalized_name, :slug, uniqueness: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at id name normalized_name retail_brand_id slug updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[products retail_brand]
  end
end
