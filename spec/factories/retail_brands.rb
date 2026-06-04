FactoryBot.define do
  factory :retail_brand do
    name { Faker::Company.unique.name }
    slug { Faker::Internet.unique.slug }
    aliases { [] }
  end
end
