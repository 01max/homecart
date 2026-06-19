FactoryBot.define do
  factory :category do
    sequence(:name) { |number| "Category #{number}" }
    normalized_name { ProductCatalog::NormalizeTextService.call(name) }
    slug { name.parameterize }

    trait :with_parent do
      association :parent, factory: :category
    end
  end
end
