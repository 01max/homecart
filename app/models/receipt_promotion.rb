class ReceiptPromotion < ApplicationRecord
  enum :unit, {
    euro_cents: "euro_cents",
    vignette_count: "vignette_count"
  }, validate: true

  enum :kind, {
    loyalty_credit: "loyalty_credit",
    immediate_discount: "immediate_discount",
    coupon: "coupon",
    points_accrual: "points_accrual"
  }, prefix: true, validate: true

  enum :linking_method, {
    parser_inferred: "parser_inferred",
    user_confirmed: "user_confirmed",
    unallocated: "unallocated"
  }, prefix: true, validate: true

  belongs_to :receipt, inverse_of: :receipt_promotions
  belongs_to :linked_line, class_name: "ReceiptLine", inverse_of: :receipt_promotions, optional: true

  validates :program, :unit, :kind, :linking_method, presence: true
  validates :delta, presence: true, numericality: { only_integer: true }
  validate :linking_method_matches_linked_line

  private

  def linking_method_matches_linked_line
    if linked_line_id.nil? && linking_method != "unallocated"
      errors.add(:linking_method, :must_be_unallocated_without_linked_line)
    elsif linked_line_id.present? && linking_method == "unallocated"
      errors.add(:linking_method, :cannot_be_unallocated_with_linked_line)
    end
  end
end
