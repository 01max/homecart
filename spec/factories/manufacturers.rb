FactoryBot.define do
  factory :manufacturer do
    sequence(:name) { |number| "Manufacturer #{number}" }
    normalized_name { ProductCatalog::NormalizeTextService.call(name) }
    slug { name.parameterize }
  end
end
