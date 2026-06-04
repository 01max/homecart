module DatabaseHelpers
  def execute_in_savepoint(sql)
    ActiveRecord::Base.transaction(requires_new: true) do
      ActiveRecord::Base.connection.execute(sql)
    end
  end
end

RSpec.configure do |config|
  config.include DatabaseHelpers
end
