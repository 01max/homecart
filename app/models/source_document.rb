# Immutable source receipt file selected by the user for ingestion.
#
# A source document owns the original Active Storage attachment, its content
# hash, MIME type, selected store, and parser format. Re-upload deduplication is
# based on `content_hash`.
class SourceDocument < ApplicationRecord
  include EvidenceImmutable

  MIME_TYPES = {
    pdf: "application/pdf",
    png: "image/png",
    jpeg: "image/jpeg"
  }.freeze

  PARSER_FORMATS = Parser::Registry::FORMATS

  enum :mime_type, MIME_TYPES, prefix: true, validate: true
  enum :parser_format, PARSER_FORMATS, prefix: true, validate: true

  immutable_evidence_attributes :content_hash, :mime_type, :ingested_at

  belongs_to :store, inverse_of: :source_documents
  has_one_attached :original_file
  has_many :text_extractions, inverse_of: :source_document, dependent: :restrict_with_exception
  has_many :receipts, inverse_of: :source_document, dependent: :restrict_with_exception

  validates :content_hash, presence: true, uniqueness: true, format: { with: /\A\h{64}\z/ }
  validates :mime_type, :parser_format, :ingested_at, presence: true
end
