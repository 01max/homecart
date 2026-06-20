require "rails_helper"

RSpec.describe ReceiptIngestion::DetectSourceDocumentService do
  def call_service(text_extraction)
    described_class.call(text_extraction: text_extraction)
  end

  def evidence_codes(result)
    result.evidence.pluck("code")
  end

  def expect_detection_matches_result(result)
    detection = result.detection

    expect(detection).to have_attributes(
      status: result.status,
      parser_confidence: result.parser_confidence,
      store: result.store,
      store_confidence: result.store_confidence,
      evidence: result.evidence
    )
  end

  def expect_classified_result(result, store:)
    expect(result).to be_classified
    expect(result).to have_attributes(
      parser_format: "leclerc.paper.v1",
      parser_confidence: "manual",
      store: store,
      store_confidence: "manual"
    )
    expect(evidence_codes(result)).to contain_exactly("explicit_parser_format", "explicit_store")
    expect_detection_matches_result(result)
  end

  def expect_unclassified_result(result)
    expect(result).to be_needs_classification
    expect(result).to have_attributes(
      parser_format: nil,
      parser_confidence: "none",
      store: nil,
      store_confidence: "none"
    )
    expect(evidence_codes(result)).to contain_exactly("parser_format_detection_pending", "store_detection_pending")
    expect_detection_matches_result(result)
  end

  def expect_partial_store_result(result, store:)
    expect(result).to be_needs_classification
    expect(result).to have_attributes(
      parser_format: nil,
      store: store,
      store_confidence: "manual"
    )
    expect(evidence_codes(result)).to contain_exactly("parser_format_detection_pending", "explicit_store")
  end

  it "persists a classified detection from explicit source document fields" do
    text_extraction = create(:text_extraction)
    result = nil

    expect { result = call_service(text_extraction) }
      .to change(SourceDocumentDetection, :count).by(1)

    expect_classified_result(result, store: text_extraction.source_document.store)
  end

  it "keeps the source document classified when both source fields are selected" do
    source_document = create(:source_document)
    text_extraction = create(:text_extraction, source_document: source_document)

    result = call_service(text_extraction)

    expect(result.source_document).to be_classified
    expect(source_document.reload).to be_classified
    expect(source_document).to be_parser_format_leclerc_paper_v1
    expect(source_document.store).to eq(text_extraction.source_document.store)
  end

  it "persists a needs-classification detection when no source fields are selected" do
    source_document = create(:source_document, :pending_classification)
    text_extraction = create(:text_extraction, source_document: source_document)

    result = call_service(text_extraction)

    expect_unclassified_result(result)
  end

  it "marks the source document as needing classification without selected source fields" do
    source_document = create(:source_document, :pending_classification)
    text_extraction = create(:text_extraction, source_document: source_document)

    result = call_service(text_extraction)

    expect(result.source_document).to be_needs_classification
    expect(source_document.reload).to be_needs_classification
    expect(source_document.parser_format).to be_nil
    expect(source_document.store).to be_nil
  end

  it "preserves a partial explicit selection while keeping the document unclassified" do
    store = create(:store)
    source_document = create(:source_document, :pending_classification, store: store)
    text_extraction = create(:text_extraction, source_document: source_document)

    result = call_service(text_extraction)

    expect_partial_store_result(result, store: store)
    expect(source_document.reload.store).to eq(store)
  end
end
