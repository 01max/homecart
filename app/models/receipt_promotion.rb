# Parsed loyalty, coupon, or promotion event associated with a receipt.
#
# Promotion links to receipt lines are best-effort parser observations until the
# review workflow confirms or clears them.
class ReceiptPromotion < ApplicationRecord
  enum :unit, {
    euro_cents: "euro_cents",
    vignette_count: "vignette_count",
    point_count: "point_count"
  }, validate: true

  enum :kind, {
    loyalty_cash_credit: "loyalty_cash_credit",
    loyalty_cash_debit: "loyalty_cash_debit",
    immediate_discount: "immediate_discount",
    coupon: "coupon",
    points_accrual: "points_accrual",
    points_consumption: "points_consumption"
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

# == Schema Information
#
# Table name: receipt_promotions
#
#  program        :string           not null
#  unit           :enum             not null
#  delta          :integer          not null
#  label          :text
#  kind           :enum             not null
#  linking_method :enum             not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  id             :uuid             not null, primary key
#  receipt_id     :uuid             not null, indexed
#  linked_line_id :uuid             indexed
#
# Indexes
#
#  index_receipt_promotions_on_linked_line_id  (linked_line_id)
#  index_receipt_promotions_on_receipt_id      (receipt_id)
#
