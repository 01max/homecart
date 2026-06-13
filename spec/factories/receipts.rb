FactoryBot.define do
  factory :receipt do
    association :store
    source_document { association(:source_document, store: store) }
    text_extraction { association(:text_extraction, source_document: source_document) }
    parser_format { "leclerc.paper.v1" }
    purchased_at { Time.current }
    total_cents { 1_234 }
    declared_article_count { 2 }
    parser_status { "needs_review" }
    parser_warnings { [] }

    trait :reviewed do
      parser_status { "reviewed" }
    end
  end
end
