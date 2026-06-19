FactoryBot.define do
  factory :price_observation do
    association :receipt_line_match, status: "confirmed"
    receipt_line { receipt_line_match.receipt_line }
    product_variant { receipt_line_match.product_variant }
    store { receipt_line.receipt.store }
    observed_at { receipt_line.receipt.purchased_at || Time.current }
    purchased_quantity { receipt_line.quantity }
    purchased_unit { receipt_line.unit_of_measure }
    total_cents { receipt_line.total_cents }
    pack_unit_price_cents { total_cents }
    comparison_unit { nil }
    comparison_unit_price_cents { nil }
    source { "receipt_line" }

    trait :with_comparison_unit_price do
      association :comparison_unit
      comparison_unit_price_cents { 456 }
    end
  end
end
