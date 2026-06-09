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

  private

  def parent_is_not_self
    errors.add(:parent, :self_parent) if parent_id.present? && parent_id == id
  end
end
