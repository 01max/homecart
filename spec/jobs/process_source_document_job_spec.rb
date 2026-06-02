require "rails_helper"

RSpec.describe ProcessSourceDocumentJob do
  it "runs on the receipt handling queue" do
    expect(described_class.queue_name).to eq("receipt_handling")
  end

  it "delegates extraction to the service" do
    source_document = create_source_document
    text_extraction = create_text_extraction(source_document: source_document)

    allow(ReceiptIngestion::ExtractTextService).to receive(:call).and_return(text_extraction)
    allow(ParseReceiptJob).to receive(:perform_later)

    described_class.perform_now(source_document)

    expect(ReceiptIngestion::ExtractTextService).to have_received(:call).with(source_document: source_document)
  end

  it "enqueues parsing for a successful text extraction" do
    source_document = create_source_document
    text_extraction = create_text_extraction(source_document: source_document)

    allow(ReceiptIngestion::ExtractTextService).to receive(:call).and_return(text_extraction)
    allow(ParseReceiptJob).to receive(:perform_later)

    described_class.perform_now(source_document)

    expect(ParseReceiptJob).to have_received(:perform_later).with(text_extraction.id)
  end

  it "does not enqueue parsing for a failed text extraction" do
    source_document = create_source_document
    text_extraction = create_text_extraction(source_document: source_document, success: false)

    allow(ReceiptIngestion::ExtractTextService).to receive(:call).and_return(text_extraction)
    allow(ParseReceiptJob).to receive(:perform_later)

    described_class.perform_now(source_document)

    expect(ParseReceiptJob).not_to have_received(:perform_later)
  end
end
