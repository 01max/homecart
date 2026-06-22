FactoryBot.define do
  factory :source_document_detection do
    source_document
    text_extraction { association(:text_extraction, source_document: source_document) }
    status { "classified" }
    parser_format { source_document.parser_format || "leclerc.paper.v1" }
    parser_confidence { "manual" }
    store { source_document.store }
    store_confidence { "manual" }
    evidence { [ { "code" => "factory" } ] }

    trait :needs_classification do
      status { "needs_classification" }
      parser_format { nil }
      parser_confidence { "none" }
      store { nil }
      store_confidence { "none" }
      evidence { [ { "code" => "missing_source_match" } ] }
    end
  end
end
