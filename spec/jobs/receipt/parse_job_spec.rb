require "rails_helper"

RSpec.describe Receipt::ParseJob do
  let(:broadcaster) { class_spy(ReceiptIngestion::BroadcastProcessingStatusService) }

  def stub_successful_parse(text_extraction)
    receipt = create_receipt(
      store: text_extraction.source_document.store,
      source_document: text_extraction.source_document,
      text_extraction: text_extraction
    )
    result = ReceiptIngestion::ParseService::Result.new(receipt: receipt, lines: [], promotions: [], payments: [])
    allow(ReceiptIngestion::ParseService).to receive(:call).and_return(result)
    receipt
  end

  def perform_job(text_extraction)
    described_class.perform_now(text_extraction.id, broadcaster: broadcaster)
  end

  def expect_parsing_broadcast(text_extraction, parsing_state:, receipt: nil)
    expected_arguments = {
      source_document: text_extraction.source_document,
      text_extraction: text_extraction,
      extraction_state: "complete",
      parsing_state: parsing_state
    }
    expected_arguments[:receipt] = receipt if receipt

    expect(broadcaster).to have_received(:call).with(expected_arguments)
  end

  it "runs on the receipt handling queue" do
    expect(described_class.queue_name).to eq("receipt_handling")
  end

  it "loads the text extraction and delegates parsing to the service" do
    text_extraction = create_text_extraction
    receipt = stub_successful_parse(text_extraction)

    perform_job(text_extraction)

    expect(ReceiptIngestion::ParseService).to have_received(:call).with(text_extraction: text_extraction)
    expect_parsing_broadcast(text_extraction, parsing_state: "running")
    expect_parsing_broadcast(text_extraction, receipt: receipt, parsing_state: "complete")
  end

  it "does not parse failed text extractions" do
    text_extraction = create_text_extraction(success: false)

    allow(ReceiptIngestion::ParseService).to receive(:call)

    perform_job(text_extraction)

    expect(ReceiptIngestion::ParseService).not_to have_received(:call)
    expect(broadcaster).not_to have_received(:call)
  end

  it "discards missing text extraction records" do
    allow(ReceiptIngestion::ParseService).to receive(:call)

    described_class.perform_now(SecureRandom.uuid, broadcaster: broadcaster)

    expect(ReceiptIngestion::ParseService).not_to have_received(:call)
    expect(broadcaster).not_to have_received(:call)
  end
end
