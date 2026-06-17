# Product-identification decision recorded separately from receipt evidence.
class ReceiptLineMatch < ApplicationRecord
  enum :status, {
    suggested: "suggested",
    confirmed: "confirmed",
    rejected: "rejected",
    ignored: "ignored"
  }, validate: true

  enum :source, {
    user: "user",
    heuristic: "heuristic"
  }, prefix: true, validate: true

  belongs_to :receipt_line, inverse_of: :receipt_line_matches
  belongs_to :product_variant, inverse_of: :receipt_line_matches, optional: true

  has_one :price_observation, inverse_of: :receipt_line_match, dependent: :restrict_with_exception

  validates :status, :source, :label_snapshot, presence: true
  validates :confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true
  validates :product_variant, presence: true, unless: :ignored?
  validates :product_variant, absence: true, if: :ignored?
  validates :receipt_line_id,
            uniqueness: { conditions: -> { terminal_decisions } },
            if: :terminal_decision?

  scope :terminal_decisions, -> { where(status: %w[ confirmed ignored ]) }

  def terminal_decision?
    confirmed? || ignored?
  end
end

# == Schema Information
#
# Table name: receipt_line_matches
#
#  id                 :uuid             not null, primary key
#  receipt_line_id    :uuid             not null, indexed, indexed => [status], indexed
#  product_variant_id :uuid             indexed, indexed => [status]
#  status             :enum             not null, indexed => [product_variant_id], indexed => [receipt_line_id]
#  source             :enum             not null
#  confidence         :decimal(5, 4)
#  label_snapshot     :text             not null
#  decided_at         :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_receipt_line_matches_on_product_variant_id             (product_variant_id)
#  index_receipt_line_matches_on_product_variant_id_and_status  (product_variant_id,status)
#  index_receipt_line_matches_on_receipt_line_id                (receipt_line_id)
#  index_receipt_line_matches_on_receipt_line_id_and_status     (receipt_line_id,status)
#  index_receipt_line_matches_on_terminal_decision              (receipt_line_id) UNIQUE
#
