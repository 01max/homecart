FactoryBot.define do
  factory :product do
    association :category
    manufacturer { nil }
    association :product_brand
    sequence(:name) { |number| "Product #{number}" }
    normalized_name { ProductCatalog::NormalizeTextService.call(name) }
    slug { name.parameterize }

    trait :with_manufacturer do
      association :manufacturer
    end
  end
end
