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

# == Schema Information
#
# Table name: product_brands
#
#  id              :uuid             not null, primary key
#  name            :string           not null
#  normalized_name :string           not null, indexed
#  slug            :string           not null, indexed
#  retail_brand_id :uuid             indexed
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_product_brands_on_normalized_name  (normalized_name) UNIQUE
#  index_product_brands_on_retail_brand_id  (retail_brand_id)
#  index_product_brands_on_slug             (slug) UNIQUE
#
