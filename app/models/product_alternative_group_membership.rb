# Joins a product variant to an alternative group with an equivalence level.
class ProductAlternativeGroupMembership < ApplicationRecord
  enum :equivalence, {
    equivalent: "equivalent",
    comparable_size: "comparable_size",
    different_size: "different_size"
  }, validate: true

  belongs_to :product_alternative_group, inverse_of: :product_alternative_group_memberships
  belongs_to :product_variant, inverse_of: :product_alternative_group_memberships

  validates :equivalence, presence: true
  validates :product_variant_id, uniqueness: { scope: :product_alternative_group_id }
end
