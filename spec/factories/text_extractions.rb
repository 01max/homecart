FactoryBot.define do
  factory :text_extraction do
    association :source_document
    engine { "pdftotext-layout" }
    text { Faker::Lorem.paragraph }
    ran_at { Time.current }
    success { true }
    error_message { nil }

    trait :failed do
      text { "" }
      success { false }
      error_message { Faker::Lorem.sentence }
    end
  end
end
