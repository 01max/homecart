class SourceDocument < ApplicationRecord
  MIME_TYPES = {
    pdf: "application/pdf",
    png: "image/png",
    jpeg: "image/jpeg"
  }.freeze

  PARSER_FORMATS = {
    auchan_paper_v1: "auchan.paper.v1",
    leclerc_paper_v1: "leclerc.paper.v1",
    leclerc_paper_v2: "leclerc.paper.v2",
    leclerc_web_v1: "leclerc.web.v1",
    u_paper_v1: "u.paper.v1",
    u_paper_v2: "u.paper.v2"
  }.freeze

  enum :mime_type, MIME_TYPES, prefix: true, validate: true
  enum :parser_format, PARSER_FORMATS, prefix: true, validate: true

  belongs_to :store, inverse_of: :source_documents
  has_one_attached :original_file
  has_many :text_extractions, inverse_of: :source_document, dependent: :restrict_with_exception
  has_many :receipts, inverse_of: :source_document, dependent: :restrict_with_exception

  validates :content_hash, presence: true, uniqueness: true, format: { with: /\A\h{64}\z/ }
  validates :mime_type, :parser_format, :ingested_at, presence: true
end
