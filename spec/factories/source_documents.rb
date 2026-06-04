FactoryBot.define do
  sequence(:source_document_content_hash) { |number| Digest::SHA256.hexdigest("source-document-#{number}") }

  factory :source_document do
    association :store
    content_hash { generate(:source_document_content_hash) }
    mime_type { "application/pdf" }
    parser_format { "leclerc.paper.v1" }
    ingested_at { Time.current }
  end
end
