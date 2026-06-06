FactoryBot.define do
  factory :receipt_promotion do
    association :receipt
    program { Faker::Commerce.promotion_code }
    unit { "euro_cents" }
    delta { 100 }
    label { Faker::Commerce.promotion_code }
    linked_line { nil }
    kind { "loyalty_cash_credit" }
    linking_method { "unallocated" }
  end
end
