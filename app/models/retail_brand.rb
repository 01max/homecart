# Retailer identity shared by one or more stores.
#
# This is separate from future product/manufacturer brands so receipt queries can
# group by retailer without overloading product identity.
class RetailBrand < ApplicationRecord
  has_many :product_brands, inverse_of: :retail_brand, dependent: :restrict_with_exception
  has_many :stores, inverse_of: :retail_brand, dependent: :restrict_with_exception

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validate :aliases_are_an_array

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at id name slug updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[product_brands stores]
  end

  private

  def aliases_are_an_array
    errors.add(:aliases, :not_an_array) unless aliases.is_a?(Array)
  end
end

# == Schema Information
#
# Table name: retail_brands
#
#  name       :string           not null
#  slug       :string           not null, indexed
#  aliases    :jsonb            default("[]"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  id         :uuid             not null, primary key
#
# Indexes
#
#  index_retail_brands_on_slug  (slug) UNIQUE
#
