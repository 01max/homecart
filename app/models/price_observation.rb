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

  scope :for_variant, ->(variant) { where(product_variant: variant) }
  scope :for_store, ->(store) { where(store: store) }
  scope :recent_first, -> { order(observed_at: :desc, id: :desc) }
  scope :variant_store_history, ->(variant, store) { for_variant(variant).for_store(store).recent_first }
end
