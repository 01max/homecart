# Category-scoped group of variants that can substitute for one another.
class ProductAlternativeGroup < ApplicationRecord
  belongs_to :category, inverse_of: :product_alternative_groups

  has_many :product_alternative_group_memberships,
           inverse_of: :product_alternative_group,
           dependent: :restrict_with_exception
  has_many :product_variants, through: :product_alternative_group_memberships

  validates :name, presence: true
  validates :name, uniqueness: { scope: :category_id }

  def self.ransackable_attributes(_auth_object = nil)
    %w[category_id created_at id name updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[category product_alternative_group_memberships product_variants]
  end
end

# == Schema Information
#
# Table name: product_alternative_groups
#
#  id          :uuid             not null, primary key
#  category_id :uuid             not null, indexed, indexed => [name]
#  name        :string           not null, indexed => [category_id]
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_product_alternative_groups_on_category_id           (category_id)
#  index_product_alternative_groups_on_category_id_and_name  (category_id,name) UNIQUE
#
