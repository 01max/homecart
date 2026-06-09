FactoryBot.define do
  factory :product_variant do
    association :comparison_unit
    association :product
    sequence(:name) { |number| "Product Variant #{number}" }
    normalized_name { ProductCatalog::NormalizeTextService.call(name) }
    slug { name.parameterize }
    package_count { 1 }
    quantity_value { 1.0 }
    barcode { nil }

    trait :with_barcode do
      sequence(:barcode) { |number| "376000000#{number.to_s.rjust(5, '0')}" }
    end

    trait :without_barcode do
      barcode { nil }
    end

    trait :without_comparison_unit do
      comparison_unit { nil }
      quantity_value { nil }
    end
  end
end
