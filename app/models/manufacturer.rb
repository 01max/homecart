# Company responsible for manufacturing one or more products.
class Manufacturer < ApplicationRecord
  has_many :products, inverse_of: :manufacturer, dependent: :restrict_with_exception

  validates :name, :normalized_name, :slug, presence: true
  validates :normalized_name, :slug, uniqueness: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at id name normalized_name slug updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[products]
  end
end

# == Schema Information
#
# Table name: manufacturers
#
#  id              :uuid             not null, primary key
#  name            :string           not null
#  normalized_name :string           not null, indexed
#  slug            :string           not null, indexed
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_manufacturers_on_normalized_name  (normalized_name) UNIQUE
#  index_manufacturers_on_slug             (slug) UNIQUE
#
