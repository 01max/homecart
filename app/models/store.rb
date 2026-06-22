# User-curated retail location or channel selected at upload time.
#
# Parsers never infer stores from receipt headers; receipts copy their store from
# the selected source document.
class Store < ApplicationRecord
  enum :channel, {
    physical: "physical",
    drive: "drive",
    click_collect: "click_collect"
  }, validate: true

  belongs_to :retail_brand, inverse_of: :stores
  has_many :source_documents, inverse_of: :store, dependent: :restrict_with_exception
  has_many :source_document_detections, inverse_of: :store, dependent: :restrict_with_exception
  has_many :receipts, inverse_of: :store, dependent: :restrict_with_exception
  has_many :price_observations, inverse_of: :store, dependent: :restrict_with_exception

  validates :location_name, presence: true
  validates :channel, presence: true
  validates :location_name, uniqueness: { scope: [ :retail_brand_id, :channel ] }
  validate :identifiers_are_an_object

  def self.ransackable_attributes(_auth_object = nil)
    %w[channel created_at id location_name retail_brand_id updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[price_observations receipts retail_brand source_document_detections source_documents]
  end

  private

  def identifiers_are_an_object
    errors.add(:identifiers, :not_an_object) unless identifiers.is_a?(Hash)
  end
end

# == Schema Information
#
# Table name: stores
#
#  location_name   :string           not null, indexed => [retail_brand_id, channel]
#  channel         :enum             not null, indexed => [retail_brand_id, location_name]
#  address         :text
#  identifiers     :jsonb            default("{}"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  id              :uuid             not null, primary key
#  retail_brand_id :uuid             not null, indexed, indexed => [location_name, channel]
#
# Indexes
#
#  index_stores_on_retail_brand_id                                (retail_brand_id)
#  index_stores_on_retail_brand_id_and_location_name_and_channel  (retail_brand_id,location_name,channel) UNIQUE
#
