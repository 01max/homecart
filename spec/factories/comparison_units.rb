FactoryBot.define do
  factory :comparison_unit do
    sequence(:name) { |number| "Comparison Unit #{number}" }
    sequence(:symbol) { |number| "u#{number}" }
    normalized_name { name.downcase }
    slug { name.parameterize }
  end
end
