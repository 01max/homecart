require "rails_helper"

RSpec.describe ReceiptIngestion::DetectSourceDocumentService do
  parser_fixture_examples = {
    "auchan.paper.v1" => "auchan_paper_v1_cashier.txt",
    "leclerc.paper.v1" => "leclerc_paper_v1_receipt_level_discounts.txt",
    "leclerc.paper.v2" => "leclerc_paper_v2_quantity_vat.txt",
    "leclerc.web.v1" => "leclerc_web_v1_drive.txt",
    "u.paper.v1" => "u_paper_v1_direct_items.txt",
    "u.paper.v2" => "u_paper_v2_single_payment.txt"
  }

  def call_service(text_extraction)
    described_class.call(text_extraction: text_extraction)
  end

  def fixture_text(filename)
    Rails.root.join("spec/fixtures/files/parser", filename).read
  end

  def evidence_codes(result)
    result.evidence.pluck("code")
  end

  def parser_format_key(parser_format)
    parser_format.tr(".", "_")
  end

  def text_extraction_for(text, source_document: source_document_with_store_hint)
    create(:text_extraction, source_document: source_document, text: text)
  end

  def source_document_with_store_hint
    create(:source_document, :pending_classification, store: create(:store))
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

  def expect_detected_parser_format(result, parser_format)
    expect(result).to have_attributes(parser_format: parser_format, parser_confidence: "high")
    expect(result.detection.parser_format).to eq(parser_format_key(parser_format))
    expect(result.source_document.parser_format).to eq(parser_format_key(parser_format))
    expect(result.evidence).to include(
      a_hash_including("code" => "parser_format_marker", "parser_format" => parser_format)
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
    expect(evidence_codes(result)).to contain_exactly("parser_format_not_detected", "store_detection_pending")
    expect_detection_matches_result(result)
  end

  def expect_partial_store_result(result, store:)
    expect(result).to be_needs_classification
    expect(result).to have_attributes(
      parser_format: nil,
      store: store,
      store_confidence: "manual"
    )
    expect(evidence_codes(result)).to contain_exactly("parser_format_not_detected", "explicit_store")
  end

  parser_fixture_examples.each do |parser_format, filename|
    it "detects #{parser_format} from extracted text markers" do
      result = call_service(text_extraction_for(fixture_text(filename)))

      expect(result).to be_classified
      expect_detected_parser_format(result, parser_format)
      expect(result.detection.parser_confidence).to eq("high")
    end
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

  it "keeps a detected parser format when store classification is still missing" do
    source_document = create(:source_document, :pending_classification)
    text_extraction = text_extraction_for(fixture_text("leclerc_web_v1_drive.txt"), source_document: source_document)

    result = call_service(text_extraction)

    expect(result).to be_needs_classification
    expect_detected_parser_format(result, "leclerc.web.v1")
    expect(result.store).to be_nil
  end

  it "blocks parser selection when incompatible hard markers match" do
    source_document = source_document_with_store_hint
    text_extraction = text_extraction_for("CB Web Drive\nOmniPOS version\n", source_document: source_document)

    result = call_service(text_extraction)

    expect(result).to be_needs_classification
    expect(result).to have_attributes(parser_format: nil, parser_confidence: "none")
    expect(evidence_codes(result)).to include("parser_format_ambiguous")
    expect(result.source_document.parser_format).to be_nil
  end
end
