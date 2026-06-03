require "rails_helper"

RSpec.describe ReceiptIngestion::BroadcastProcessingStatusService do
  include ActionView::RecordIdentifier

  before do
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
  end

  def expect_source_document_replace(source_document, target:, partial:, locals:)
    expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
      source_document,
      target: target,
      partial: partial,
      locals: hash_including(locals)
    )
  end

  def expect_receipt_list_replace(stream_name, target, selected_parser_status)
    expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
      stream_name,
      target: target,
      partial: "receipts/list",
      locals: hash_including(selected_parser_status: selected_parser_status)
    )
  end

  def broadcast_source_document(source_document, text_extraction)
    described_class.call(
      source_document: source_document,
      text_extraction: text_extraction,
      extraction_state: "complete",
      parsing_state: "queued"
    )
  end

  def broadcast_receipt(receipt)
    described_class.call(
      source_document: receipt.source_document,
      text_extraction: receipt.text_extraction,
      receipt: receipt,
      extraction_state: "complete",
      parsing_state: "complete"
    )
  end

  def expect_processing_status_replace(source_document, text_extraction)
    expect_source_document_replace(
      source_document,
      target: dom_id(source_document, :processing_status),
      partial: "source_documents/processing_status",
      locals: {
        source_document: source_document,
        latest_text_extraction: text_extraction,
        extraction_state: "complete",
        parsing_state: "queued"
      }
    )
  end

  def expect_latest_extraction_replace(source_document, text_extraction)
    expect_source_document_replace(
      source_document,
      target: dom_id(source_document, :latest_text_extraction),
      partial: "source_documents/latest_extraction",
      locals: { latest_text_extraction: text_extraction }
    )
  end

  def expect_receipt_summary_replace(source_document)
    expect_source_document_replace(
      source_document,
      target: dom_id(source_document, :receipt_summary),
      partial: "source_documents/receipt_summary",
      locals: { source_document: source_document }
    )
  end

  it "broadcasts replace updates for source document status sections" do
    source_document = create_source_document
    text_extraction = create_text_extraction(source_document: source_document)

    broadcast_source_document(source_document, text_extraction)

    expect_processing_status_replace(source_document, text_extraction)
    expect_latest_extraction_replace(source_document, text_extraction)
    expect_receipt_summary_replace(source_document)
  end

  it "broadcasts receipt list replacements for unfiltered and status-filtered indexes" do
    receipt = create_receipt(parser_status: "parsed")

    broadcast_receipt(receipt)

    expect_receipt_list_replace("receipts", "receipts_list", nil)
    expect_receipt_list_replace("receipts:parsed", "receipts_list_parsed", "parsed")
  end
end
