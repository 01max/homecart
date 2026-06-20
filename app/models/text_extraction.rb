# Append-only record of one text extraction attempt for a source document.
#
# Successful records preserve the raw extracted text. Failed records preserve the
# engine identifier and error message so parsing can be skipped without losing
# evidence of the attempted extraction.
class TextExtraction < ApplicationRecord
  include EvidenceImmutable

  immutable_evidence_attributes :source_document_id, :engine, :text, :ran_at, :success, :error_message

  belongs_to :source_document, inverse_of: :text_extractions
  has_one :receipt, inverse_of: :text_extraction, dependent: :restrict_with_exception
  has_many :source_document_detections, inverse_of: :text_extraction, dependent: :restrict_with_exception

  validates :engine, :ran_at, presence: true
  validates :success, inclusion: { in: [ true, false ] }
  validates :text, presence: true, if: :success?
  validates :error_message, presence: true, unless: :success?
end

# == Schema Information
#
# Table name: text_extractions
#
#  engine             :string           not null
#  text               :text             default(""), not null
#  ran_at             :datetime         not null
#  success            :boolean          default(FALSE), not null
#  error_message      :text
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  id                 :uuid             not null, primary key
#  source_document_id :uuid             not null, indexed
#
# Indexes
#
#  index_text_extractions_on_source_document_id  (source_document_id)
#
