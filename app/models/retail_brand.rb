# Retailer identity shared by one or more stores.
#
# This is separate from future product/manufacturer brands so receipt queries can
# group by retailer without overloading product identity.
class RetailBrand < ApplicationRecord
  has_many :stores, inverse_of: :retail_brand, dependent: :restrict_with_exception

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validate :aliases_are_an_array

  private

  def aliases_are_an_array
    errors.add(:aliases, :not_an_array) unless aliases.is_a?(Array)
  end
end
