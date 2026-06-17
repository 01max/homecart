# Hierarchical category used to organize products and comparable alternatives.
class Category < ApplicationRecord
  belongs_to :parent, class_name: "Category", inverse_of: :children, optional: true

  has_many :children,
           class_name: "Category",
           foreign_key: :parent_id,
           inverse_of: :parent,
           dependent: :restrict_with_exception
  has_many :product_alternative_groups, inverse_of: :category, dependent: :restrict_with_exception
  has_many :products, inverse_of: :category, dependent: :restrict_with_exception

  validates :name, :normalized_name, :slug, presence: true
  validates :normalized_name, :slug, uniqueness: true
  validate :parent_is_not_self

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at id name normalized_name parent_id slug updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[children parent product_alternative_groups products]
  end

  private

  def parent_is_not_self
    errors.add(:parent, :self_parent) if parent_id.present? && parent_id == id
  end
end

# == Schema Information
#
# Table name: categories
#
#  id              :uuid             not null, primary key
#  name            :string           not null
#  normalized_name :string           not null, indexed
#  slug            :string           not null, indexed
#  parent_id       :uuid             indexed
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_categories_on_normalized_name  (normalized_name) UNIQUE
#  index_categories_on_parent_id        (parent_id)
#  index_categories_on_slug             (slug) UNIQUE
#
