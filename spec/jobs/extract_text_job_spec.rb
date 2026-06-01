require "rails_helper"

RSpec.describe ExtractTextJob do
  it "runs on the receipt extraction queue" do
    expect(described_class.queue_name).to eq("receipt_handling")
  end

  it "delegates extraction to the service" do
    source_document = create_source_document

    allow(ReceiptIngestion::ExtractTextService).to receive(:call)

    described_class.perform_now(source_document)

    expect(ReceiptIngestion::ExtractTextService).to have_received(:call).with(source_document: source_document)
  end
end
