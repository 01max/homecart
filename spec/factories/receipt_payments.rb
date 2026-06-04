FactoryBot.define do
  factory :receipt_payment do
    association :receipt
    sequence(:position) { |number| number }
    raw_label { Faker::Business.credit_card_type }
    category { "bank_card" }
    amount_cents { 1_234 }
  end
end
