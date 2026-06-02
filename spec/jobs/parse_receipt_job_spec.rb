require "rails_helper"

RSpec.describe ParseReceiptJob do
  it "runs on the receipt handling queue" do
    expect(described_class.queue_name).to eq("receipt_handling")
  end

  it "loads the text extraction and delegates parsing to the service" do
    text_extraction = create_text_extraction

    allow(ReceiptIngestion::ParseService).to receive(:call)

    described_class.perform_now(text_extraction.id)

    expect(ReceiptIngestion::ParseService).to have_received(:call).with(text_extraction: text_extraction)
  end

  it "does not parse failed text extractions" do
    text_extraction = create_text_extraction(success: false)

    allow(ReceiptIngestion::ParseService).to receive(:call)

    described_class.perform_now(text_extraction.id)

    expect(ReceiptIngestion::ParseService).not_to have_received(:call)
  end

  it "discards missing text extraction records" do
    allow(ReceiptIngestion::ParseService).to receive(:call)

    described_class.perform_now(SecureRandom.uuid)

    expect(ReceiptIngestion::ParseService).not_to have_received(:call)
  end
end
