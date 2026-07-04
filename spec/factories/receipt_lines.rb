FactoryBot.define do
  factory :receipt_line do
    association :receipt
    sequence(:position) { |number| number }
    raw_text { "#{label}  12.34" }
    source_reference { nil }
    label { Faker::Commerce.product_name }
    label_truncated { false }
    quantity { 1 }
    unit_of_measure { "piece" }
    total_cents { 1_234 }
    tr_eligible { false }
    kind { "item" }
  end
end
