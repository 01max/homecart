# Immutable source receipt file selected by the user for ingestion.
#
# A source document owns the original Active Storage attachment, its content
# hash, MIME type, and current source classification. Re-upload deduplication is
# based on `content_hash`.
class SourceDocument < ApplicationRecord
  include EvidenceImmutable

  MIME_TYPES = {
    pdf: "application/pdf",
    png: "image/png",
    jpeg: "image/jpeg"
  }.freeze

  PARSER_FORMATS = Parser::Registry::FORMATS
  SOURCE_DETECTION_STATUSES = {
    pending: "pending",
    classified: "classified",
    needs_classification: "needs_classification"
  }.freeze

  enum :mime_type, MIME_TYPES, prefix: true, validate: true
  enum :parser_format, PARSER_FORMATS, prefix: true, validate: { allow_nil: true }
  enum :source_detection_status, SOURCE_DETECTION_STATUSES, validate: true

  immutable_evidence_attributes :content_hash, :mime_type, :ingested_at

  belongs_to :store, inverse_of: :source_documents, optional: true
  has_one_attached :original_file
  has_many :text_extractions, inverse_of: :source_document, dependent: :restrict_with_exception
  has_many :source_document_detections, inverse_of: :source_document, dependent: :restrict_with_exception
  has_many :receipts, inverse_of: :source_document, dependent: :restrict_with_exception

  validates :content_hash, presence: true, uniqueness: true, format: { with: /\A\h{64}\z/ }
  validates :mime_type, :ingested_at, :source_detection_status, presence: true
  validates :store, :parser_format, presence: true, if: :classified?
end

# == Schema Information
#
# Table name: source_documents
#
#  content_hash            :string           not null, indexed
#  mime_type               :enum             not null
#  ingested_at             :datetime         not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  parser_format           :enum
#  id                      :uuid             not null, primary key
#  store_id                :uuid             indexed
#  source_detection_status :enum             default("pending"), not null
#
# Indexes
#
#  index_source_documents_on_content_hash  (content_hash) UNIQUE
#  index_source_documents_on_store_id      (store_id)
#
