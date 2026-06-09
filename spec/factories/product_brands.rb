FactoryBot.define do
  factory :product_brand do
    sequence(:name) { |number| "Product Brand #{number}" }
    normalized_name { name.downcase }
    slug { name.parameterize }

    trait :private_label do
      association :retail_brand
      name { "#{retail_brand.name} private label" }
      normalized_name { name.downcase }
      slug { name.parameterize }
    end
  end
end
