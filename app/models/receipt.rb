# Structured parser output for one source document and text extraction.
#
# Receipts own parsed lines, promotions, payments, parser status, and structured
# parser warnings. They are editable during review, unlike source evidence.
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

  accepts_nested_attributes_for :receipt_lines, allow_destroy: true, reject_if: :blank_receipt_line_attributes?
  accepts_nested_attributes_for :receipt_promotions, allow_destroy: true, reject_if: :blank_receipt_promotion_attributes?
  accepts_nested_attributes_for :receipt_payments, allow_destroy: true, reject_if: :blank_receipt_payment_attributes?

  validates :parser_format, :parser_status, presence: true
  validates :total_cents, numericality: { only_integer: true }, allow_nil: true
  validates :declared_article_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :parser_warnings_are_an_array

  ransacker :parser_format_text do
    Arel.sql("receipts.parser_format::text")
  end

  ransacker :parser_status_text do
    Arel.sql("receipts.parser_status::text")
  end

  scope :recent_first, -> { order(purchased_at: :desc, id: :desc) }

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      created_at declared_article_count id parser_format parser_format_text parser_status parser_status_text purchased_at
      source_document_id store_id text_extraction_id ticket_number total_cents updated_at
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[receipt_lines receipt_payments receipt_promotions source_document store text_extraction]
  end

  private

  def blank_receipt_line_attributes?(attributes)
    attributes.except(
      "id",
      "_destroy",
      "position",
      "quantity",
      "unit_of_measure",
      "kind",
      "tr_eligible",
      "label_truncated"
    ).values.all?(&:blank?)
  end

  def blank_receipt_promotion_attributes?(attributes)
    attributes.except(
      "id",
      "_destroy",
      "unit",
      "kind",
      "linking_method",
      "linked_line_id"
    ).values.all?(&:blank?)
  end

  def blank_receipt_payment_attributes?(attributes)
    attributes.except(
      "id",
      "_destroy",
      "position",
      "category"
    ).values.all?(&:blank?)
  end

  def parser_warnings_are_an_array
    errors.add(:parser_warnings, :not_an_array) unless parser_warnings.is_a?(Array)
  end
end

# == Schema Information
#
# Table name: receipts
#
#  parser_format          :enum             not null
#  purchased_at           :datetime         indexed => [store_id, register_number, ticket_number]
#  register_number        :string           indexed => [store_id, ticket_number, purchased_at]
#  ticket_number          :string           indexed => [store_id, register_number, purchased_at]
#  cashier_code           :string
#  total_cents            :integer
#  declared_article_count :integer
#  parser_status          :enum             default("needs_review"), not null
#  parser_warnings        :jsonb            default("[]"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  id                     :uuid             not null, primary key
#  store_id               :uuid             not null, indexed, indexed => [register_number, ticket_number, purchased_at]
#  source_document_id     :uuid             not null, indexed
#  text_extraction_id     :uuid             not null, indexed
#
# Indexes
#
#  index_receipts_on_source_document_id                  (source_document_id)
#  index_receipts_on_store_id                            (store_id)
#  index_receipts_on_store_register_ticket_purchased_at  (store_id,register_number,ticket_number,purchased_at) UNIQUE
#  index_receipts_on_text_extraction_id                  (text_extraction_id)
#
