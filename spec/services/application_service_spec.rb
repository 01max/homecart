require "rails_helper"

RSpec.describe ApplicationService do
  let(:service_class) do
    Class.new(described_class) do
      def initialize(value)
        @value = value
      end

      def call
        @value
      end
    end
  end

  describe ".call" do
    it "provides a shared service object entrypoint" do
      expect(service_class.call("ok")).to eq("ok")
    end
  end
end
