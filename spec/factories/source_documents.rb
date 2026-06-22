FactoryBot.define do
  sequence(:source_document_content_hash) { |number| Digest::SHA256.hexdigest("source-document-#{number}") }

  factory :source_document do
    association :store
    content_hash { generate(:source_document_content_hash) }
    mime_type { "application/pdf" }
    parser_format { "leclerc.paper.v1" }
    source_detection_status { "classified" }
    ingested_at { Time.current }

    trait :pending_classification do
      store { nil }
      parser_format { nil }
      source_detection_status { "pending" }
    end

    trait :needs_classification do
      store { nil }
      parser_format { nil }
      source_detection_status { "needs_classification" }
    end
  end
end
