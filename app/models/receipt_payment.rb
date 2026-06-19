# Parsed payment line showing how a receipt total was settled.
#
# Multiple rows may exist for a receipt when payment is split, for example
# Tickets Restaurant plus a bank card payment.
class ReceiptPayment < ApplicationRecord
  enum :category, {
    bank_card: "bank_card",
    tickets_restaurant: "tickets_restaurant",
    cash: "cash",
    web: "web",
    other: "other"
  }, validate: true

  belongs_to :receipt, inverse_of: :receipt_payments

  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :position, uniqueness: { scope: :receipt_id }
  validates :raw_label, :category, presence: true
  validates :amount_cents, presence: true, numericality: { only_integer: true, greater_than: 0 }
end

# == Schema Information
#
# Table name: receipt_payments
#
#  position     :integer          not null, indexed => [receipt_id]
#  raw_label    :text             not null
#  category     :enum             not null
#  amount_cents :integer          not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  id           :uuid             not null, primary key
#  receipt_id   :uuid             not null, indexed, indexed => [position]
#
# Indexes
#
#  index_receipt_payments_on_receipt_id               (receipt_id)
#  index_receipt_payments_on_receipt_id_and_position  (receipt_id,position) UNIQUE
#
