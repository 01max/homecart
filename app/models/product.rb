# Catalog product grouping one or more concrete purchasable variants.
class Product < ApplicationRecord
  belongs_to :category, inverse_of: :products
  belongs_to :manufacturer, inverse_of: :products, optional: true
  belongs_to :product_brand, inverse_of: :products

  has_many :product_variants, inverse_of: :product, dependent: :restrict_with_exception

  validates :name, :normalized_name, :slug, presence: true
  validates :normalized_name, uniqueness: { scope: %i[product_brand_id category_id] }
  validates :slug, uniqueness: { scope: %i[product_brand_id category_id] }

  def self.ransackable_attributes(_auth_object = nil)
    %w[category_id created_at id manufacturer_id name normalized_name product_brand_id slug updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[category manufacturer product_brand product_variants]
  end
end

# == Schema Information
#
# Table name: products
#
#  id               :uuid             not null, primary key
#  product_brand_id :uuid             not null, indexed => [category_id, normalized_name], indexed => [category_id, slug], indexed
#  manufacturer_id  :uuid             indexed
#  category_id      :uuid             not null, indexed => [product_brand_id, normalized_name], indexed => [product_brand_id, slug], indexed
#  name             :string           not null
#  normalized_name  :string           not null, indexed => [product_brand_id, category_id]
#  slug             :string           not null, indexed => [product_brand_id, category_id]
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_products_on_brand_category_normalized_name  (product_brand_id,category_id,normalized_name) UNIQUE
#  index_products_on_brand_category_slug             (product_brand_id,category_id,slug) UNIQUE
#  index_products_on_category_id                     (category_id)
#  index_products_on_manufacturer_id                 (manufacturer_id)
#  index_products_on_product_brand_id                (product_brand_id)
#
