class TextExtraction < ApplicationRecord
  include EvidenceImmutable

  immutable_evidence_attributes :source_document_id, :engine, :text, :ran_at, :success, :error_message

  belongs_to :source_document, inverse_of: :text_extractions
  has_one :receipt, inverse_of: :text_extraction, dependent: :restrict_with_exception

  validates :engine, :ran_at, presence: true
  validates :success, inclusion: { in: [ true, false ] }
  validates :text, presence: true, if: :success?
  validates :error_message, presence: true, unless: :success?
end
