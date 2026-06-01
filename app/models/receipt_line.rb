class ReceiptLine < ApplicationRecord
  enum :unit_of_measure, {
    piece: "piece",
    kg: "kg",
    g: "g",
    l: "l",
    ml: "ml"
  }, validate: true

  enum :kind, {
    item: "item",
    fee: "fee",
    discount: "discount"
  }, prefix: true, validate: true

  belongs_to :receipt, inverse_of: :receipt_lines
  has_many :receipt_promotions, foreign_key: :linked_line_id, inverse_of: :linked_line, dependent: :restrict_with_exception

  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :position, uniqueness: { scope: :receipt_id }
  validates :raw_text, :label, :unit_of_measure, :kind, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price_cents, numericality: { only_integer: true }, allow_nil: true
  validates :total_cents, presence: true, numericality: { only_integer: true }
  validates :vat_rate_bp, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :label_truncated, :tr_eligible, inclusion: { in: [ true, false ] }
end
