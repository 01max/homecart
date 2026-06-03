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
