require "rails_helper"

RSpec.describe Receipt::ProcessSourceDocumentJob do
  let(:broadcaster) { class_spy(ReceiptIngestion::BroadcastProcessingStatusService) }

  def stub_extraction(source_document, success: true)
    create_text_extraction(source_document: source_document, success: success).tap do |text_extraction|
      allow(ReceiptIngestion::ExtractTextService).to receive(:call).and_return(text_extraction)
    end
  end

  def perform_job(source_document)
    described_class.perform_now(source_document, broadcaster: broadcaster)
  end

  def expect_running_broadcast(source_document)
    expect(broadcaster).to have_received(:call).with(
      source_document: source_document,
      extraction_state: "running",
      parsing_state: "waiting"
    )
  end

  def expect_finished_broadcast(source_document, text_extraction, extraction_state:, parsing_state:)
    expect(broadcaster).to have_received(:call).with(
      source_document: source_document,
      text_extraction: text_extraction,
      extraction_state: extraction_state,
      parsing_state: parsing_state
    )
  end

  it "runs on the receipt handling queue" do
    expect(described_class.queue_name).to eq("receipt_handling")
  end

  it "delegates extraction to the service" do
    source_document = create_source_document
    stub_extraction(source_document)

    allow(Receipt::ParseJob).to receive(:perform_later)

    perform_job(source_document)

    expect(ReceiptIngestion::ExtractTextService).to have_received(:call).with(source_document: source_document)
  end

  it "enqueues parsing for a successful text extraction" do
    source_document = create_source_document
    text_extraction = stub_extraction(source_document)

    allow(Receipt::ParseJob).to receive(:perform_later)

    perform_job(source_document)

    expect(Receipt::ParseJob).to have_received(:perform_later).with(text_extraction.id)
    expect_finished_broadcast(source_document, text_extraction, extraction_state: "complete", parsing_state: "queued")
  end

  it "does not enqueue parsing for a failed text extraction" do
    source_document = create_source_document
    text_extraction = stub_extraction(source_document, success: false)

    allow(Receipt::ParseJob).to receive(:perform_later)

    perform_job(source_document)

    expect(Receipt::ParseJob).not_to have_received(:perform_later)
    expect_finished_broadcast(source_document, text_extraction, extraction_state: "failed", parsing_state: "blocked")
  end

  it "broadcasts extraction running before delegating to the service" do
    source_document = create_source_document
    stub_extraction(source_document)

    allow(Receipt::ParseJob).to receive(:perform_later)

    perform_job(source_document)

    expect_running_broadcast(source_document)
  end
end
