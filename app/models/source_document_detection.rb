# Persisted source-classification attempt derived from extracted receipt text.
class SourceDocumentDetection < ApplicationRecord
  include EvidenceImmutable

  STATUSES = {
    classified: "classified",
    needs_classification: "needs_classification"
  }.freeze

  CONFIDENCES = {
    none: "none",
    low: "low",
    high: "high",
    manual: "manual"
  }.freeze

  enum :status, STATUSES, validate: true
  enum :parser_format, SourceDocument::PARSER_FORMATS, prefix: true, validate: { allow_nil: true }
  enum :parser_confidence, CONFIDENCES, prefix: true, validate: true
  enum :store_confidence, CONFIDENCES, prefix: true, validate: true

  immutable_evidence_attributes :source_document_id,
                                :text_extraction_id,
                                :status,
                                :parser_format,
                                :parser_confidence,
                                :store_id,
                                :store_confidence,
                                :evidence

  belongs_to :source_document, inverse_of: :source_document_detections
  belongs_to :text_extraction, inverse_of: :source_document_detections
  belongs_to :store, inverse_of: :source_document_detections, optional: true

  validates :status, :parser_confidence, :store_confidence, presence: true
  validate :classified_source_fields_present
  validate :evidence_is_an_array
  validate :text_extraction_belongs_to_source_document
  validate :parser_confidence_matches_parser_format
  validate :store_confidence_matches_store

  private

  def evidence_is_an_array
    errors.add(:evidence, :not_an_array) unless evidence.is_a?(Array)
  end

  def classified_source_fields_present
    return unless classified?

    errors.add(:parser_format, :blank) if parser_format.blank?
    errors.add(:store, :blank) if store.blank?
  end

  def text_extraction_belongs_to_source_document
    return if source_document.blank? || text_extraction.blank?
    return if text_extraction.source_document_id == source_document_id

    errors.add(:text_extraction, :source_document_mismatch)
  end

  def parser_confidence_matches_parser_format
    if parser_format.blank? && parser_confidence != "none"
      errors.add(:parser_confidence, :must_be_none_without_parser_format)
    elsif parser_format.present? && parser_confidence == "none"
      errors.add(:parser_confidence, :must_not_be_none_with_parser_format)
    end
  end

  def store_confidence_matches_store
    if store.blank? && store_confidence != "none"
      errors.add(:store_confidence, :must_be_none_without_store)
    elsif store.present? && store_confidence == "none"
      errors.add(:store_confidence, :must_not_be_none_with_store)
    end
  end
end

# == Schema Information
#
# Table name: source_document_detections
#
#  id                 :uuid             not null, primary key
#  source_document_id :uuid             not null, indexed, indexed => [created_at]
#  text_extraction_id :uuid             not null, indexed, indexed => [created_at]
#  status             :enum             not null
#  parser_format      :enum
#  parser_confidence  :enum             default("none"), not null
#  store_id           :uuid             indexed
#  store_confidence   :enum             default("none"), not null
#  evidence           :jsonb            default([]), not null
#  created_at         :datetime         not null, indexed => [source_document_id], indexed => [text_extraction_id]
#  updated_at         :datetime         not null
#
# Indexes
#
#  idx_on_source_document_id_created_at_0b2abb0abd       (source_document_id,created_at)
#  idx_on_text_extraction_id_created_at_ef13f9c5b0       (text_extraction_id,created_at)
#  index_source_document_detections_on_source_document_id  (source_document_id)
#  index_source_document_detections_on_store_id            (store_id)
#  index_source_document_detections_on_text_extraction_id  (text_extraction_id)
#
