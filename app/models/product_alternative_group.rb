# Category-scoped group of variants that can substitute for one another.
class ProductAlternativeGroup < ApplicationRecord
  belongs_to :category, inverse_of: :product_alternative_groups

  has_many :product_alternative_group_memberships,
           inverse_of: :product_alternative_group,
           dependent: :restrict_with_exception
  has_many :product_variants, through: :product_alternative_group_memberships

  validates :name, presence: true
  validates :name, uniqueness: { scope: :category_id }
end
