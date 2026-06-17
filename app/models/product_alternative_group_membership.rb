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

# == Schema Information
#
# Table name: product_alternative_group_memberships
#
#  id                           :uuid             not null, primary key
#  product_alternative_group_id :uuid             not null, indexed => [product_variant_id], indexed
#  product_variant_id           :uuid             not null, indexed => [product_alternative_group_id], indexed
#  equivalence                  :enum             not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#
# Indexes
#
#  index_alt_group_memberships_on_group_and_variant  (product_alternative_group_id,product_variant_id) UNIQUE
#  index_alt_group_memberships_on_group_id           (product_alternative_group_id)
#  index_alt_group_memberships_on_variant_id         (product_variant_id)
#
