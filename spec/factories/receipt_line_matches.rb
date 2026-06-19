FactoryBot.define do
  factory :receipt_line_match do
    association :receipt_line
    association :product_variant
    status { "confirmed" }
    source { "user" }
    confidence { nil }
    label_snapshot { receipt_line.label }
    normalized_label_snapshot { ProductCatalog::NormalizeTextService.call(label_snapshot) }
    decided_at { Time.current }

    trait :suggested do
      status { "suggested" }
      source { "heuristic" }
      confidence { 0.85 }
      decided_at { nil }
    end

    trait :rejected do
      status { "rejected" }
    end

    trait :ignored do
      product_variant { nil }
      status { "ignored" }
    end
  end
end
