FactoryBot.define do
  factory :store do
    association :retail_brand
    location_name { Faker::Address.unique.city }
    channel { "physical" }
    identifiers { {} }
  end
end
