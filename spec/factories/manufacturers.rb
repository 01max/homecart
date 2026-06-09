FactoryBot.define do
  factory :manufacturer do
    sequence(:name) { |number| "Manufacturer #{number}" }
    normalized_name { name.downcase }
    slug { name.parameterize }
  end
end
