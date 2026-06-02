class Receipt < ApplicationRecord
  PARSER_FORMATS = SourceDocument::PARSER_FORMATS

  enum :parser_format, PARSER_FORMATS, prefix: true, validate: true
  enum :parser_status, {
    parsed: "parsed",
    needs_review: "needs_review",
    reviewed: "reviewed"
  }, validate: true

  belongs_to :store, inverse_of: :receipts
  belongs_to :source_document, inverse_of: :receipts
  belongs_to :text_extraction, inverse_of: :receipt
  has_many :receipt_lines, inverse_of: :receipt, dependent: :destroy
  has_many :receipt_promotions, inverse_of: :receipt, dependent: :destroy
  has_many :receipt_payments, inverse_of: :receipt, dependent: :destroy

  validates :parser_format, :parser_status, presence: true
  validates :total_cents, numericality: { only_integer: true }, allow_nil: true
  validates :declared_article_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :parser_warnings_are_an_array

  scope :recent_first, -> { order(purchased_at: :desc, id: :desc) }

  private

  def parser_warnings_are_an_array
    errors.add(:parser_warnings, :not_an_array) unless parser_warnings.is_a?(Array)
  end
end
