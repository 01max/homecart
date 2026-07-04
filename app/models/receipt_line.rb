# Parsed receipt line preserving one observed item, fee, or discount row.
#
# Lines intentionally remain receipt observations, not product identities; v2
# matching layers can later map them to products without rewriting v1 evidence.
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
  has_many :receipt_line_matches, inverse_of: :receipt_line, dependent: :restrict_with_exception
  has_one :price_observation, inverse_of: :receipt_line, dependent: :restrict_with_exception

  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :position, uniqueness: { scope: :receipt_id }
  validates :raw_text, :label, :unit_of_measure, :kind, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price_cents, numericality: { only_integer: true }, allow_nil: true
  validates :total_cents, presence: true, numericality: { only_integer: true }
  validates :vat_rate_bp, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :label_truncated, :tr_eligible, inclusion: { in: [ true, false ] }
end

# == Schema Information
#
# Table name: receipt_lines
#
#  position         :integer          not null, indexed => [receipt_id]
#  raw_text         :text             not null
#  source_reference :text
#  label            :text             not null
#  label_truncated  :boolean          default(FALSE), not null
#  quantity         :decimal(10, 3)   default(1.0), not null
#  unit_of_measure  :enum             default("piece"), not null
#  unit_price_cents :integer
#  total_cents      :integer          not null
#  vat_rate_bp      :integer
#  tr_eligible      :boolean          default(FALSE), not null
#  section_label    :text
#  kind             :enum             default("item"), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  id               :uuid             not null, primary key
#  receipt_id       :uuid             not null, indexed, indexed => [position]
#
# Indexes
#
#  index_receipt_lines_on_receipt_id               (receipt_id)
#  index_receipt_lines_on_receipt_id_and_position  (receipt_id,position) UNIQUE
#
