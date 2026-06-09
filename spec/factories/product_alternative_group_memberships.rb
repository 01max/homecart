FactoryBot.define do
  factory :product_alternative_group_membership do
    association :product_alternative_group
    product_variant do
      association(:product_variant, product: association(:product, category: product_alternative_group.category))
    end
    equivalence { "equivalent" }

    trait :comparable_size do
      equivalence { "comparable_size" }
    end

    trait :different_size do
      equivalence { "different_size" }
    end
  end
end
