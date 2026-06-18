# Persisted product price fact proven by a confirmed receipt-line match.
class PriceObservation < ApplicationRecord
  enum :purchased_unit, {
    piece: "piece",
    kg: "kg",
    g: "g",
    l: "l",
    ml: "ml"
  }, validate: true

  enum :source, {
    receipt_line: "receipt_line"
  }, prefix: true, validate: true

  belongs_to :receipt_line_match, inverse_of: :price_observation
  belongs_to :receipt_line, inverse_of: :price_observation
  belongs_to :product_variant, inverse_of: :price_observations
  belongs_to :store, inverse_of: :price_observations
  belongs_to :comparison_unit, inverse_of: :price_observations, optional: true

  validates :observed_at, :purchased_unit, :source, presence: true
  validates :purchased_quantity, presence: true, numericality: { greater_than: 0 }
  validates :total_cents, :pack_unit_price_cents,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :comparison_unit_price_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true
  validates :comparison_unit, presence: true, if: -> { comparison_unit_price_cents.present? }
  validates :comparison_unit_price_cents, presence: true, if: -> { comparison_unit_id.present? }
  validates :receipt_line_match_id, :receipt_line_id, uniqueness: true
  validate :receipt_line_match_is_confirmed_and_consistent

  scope :for_variant, ->(variant) { where(product_variant: variant) }
  scope :for_store, ->(store) { where(store: store) }
  scope :observed_on, ->(date) { where(observed_at: date.all_day) }
  scope :recent_first, -> { order(observed_at: :desc, id: :desc) }
  scope :variant_history, ->(variant) { for_variant(variant).recent_first }
  scope :variant_store_history, ->(variant, store) { variant_history(variant).for_store(store) }

  private

  def receipt_line_match_is_confirmed_and_consistent
    return if receipt_line_match.blank?

    errors.add(:receipt_line_match, :must_be_confirmed) unless receipt_line_match.confirmed?
    return if receipt_line_match.receipt_line_id == receipt_line_id &&
      receipt_line_match.product_variant_id == product_variant_id

    errors.add(:receipt_line_match, :must_match_observation_fields)
  end
end

# == Schema Information
#
# Table name: price_observations
#
#  id                          :uuid             not null, primary key
#  receipt_line_match_id       :uuid             not null, indexed
#  receipt_line_id             :uuid             not null, indexed
#  product_variant_id          :uuid             not null, indexed, indexed => [store_id, observed_at]
#  store_id                    :uuid             not null, indexed, indexed => [observed_at], indexed => [product_variant_id, observed_at]
#  observed_at                 :datetime         not null, indexed => [store_id], indexed => [product_variant_id, store_id]
#  purchased_quantity          :decimal(10, 3)   not null
#  purchased_unit              :enum             not null
#  total_cents                 :integer          not null
#  pack_unit_price_cents       :integer          not null
#  comparison_unit_id          :uuid             indexed
#  comparison_unit_price_cents :integer
#  source                      :enum             not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#
# Indexes
#
#  index_price_observations_on_comparison_unit_id         (comparison_unit_id)
#  index_price_observations_on_product_variant_id         (product_variant_id)
#  index_price_observations_on_receipt_line_id            (receipt_line_id) UNIQUE
#  index_price_observations_on_receipt_line_match_id      (receipt_line_match_id) UNIQUE
#  index_price_observations_on_store_id                   (store_id)
#  index_price_observations_on_store_observed_at          (store_id,observed_at)
#  index_price_observations_on_variant_store_observed_at  (product_variant_id,store_id,observed_at)
#
