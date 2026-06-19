FactoryBot.define do
  factory :product_alternative_group do
    association :category
    sequence(:name) { |number| "Alternative Group #{number}" }
  end
end
