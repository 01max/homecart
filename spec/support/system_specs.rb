require "capybara/rspec"

RSpec.configure do |config|
  config.include ActiveJob::TestHelper, type: :system

  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.after(:each, type: :system) do
    clear_enqueued_jobs
    clear_performed_jobs
  end
end
