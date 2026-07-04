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

  parser_marker_examples = {
    "leclerc.web.v1" => {
      "leclerc_web_payment" => "CB Web Drive"
    },
    "leclerc.paper.v2" => {
      "leclerc_paper_vat_table" => "Code HT TVA TTC"
    },
    "leclerc.paper.v1" => {
      "leclerc_paper_legacy_ticket_line" => "01/02/26 1 ABCD 12ABC"
    },
    "u.paper.v2" => {
      "u_omnipos_version" => "OmniPOS version",
      "u_omnipos_sale_banner" => "*** VENTE ***"
    },
    "u.paper.v1" => {
      "u_legacy_hash_footer" => "Hash:",
      "u_legacy_section_marker" => ">>>> EPICERIE"
    },
    "auchan.paper.v1" => {
      "auchan_waaoh_account" => "WAAOH",
      "auchan_selfscan_section" => "Selfscan",
      "auchan_tr_totals" => "TOT. ARTICLES ELIGIBLES TR"
    }
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

  def source_document_with_parser_hint(parser_format = nil)
    parser_format ||= leclerc_paper_format
    create(:source_document, :pending_classification, parser_format: parser_format)
  end

  def source_document_with_explicit_parser(parser_format)
    create(:source_document, :pending_classification, parser_format: parser_format, store: create(:store))
  end

  def source_document_with_explicit_store(store)
    create(:source_document, :pending_classification, parser_format: leclerc_paper_format, store: store)
  end

  def leclerc_paper_format
    "leclerc.paper.v1"
  end

  def leclerc_web_format
    "leclerc.web.v1"
  end

  def store_match_sources(result)
    result.evidence.filter_map { |entry| entry["source"] if entry["code"] == "store_metadata_match" }
  end

  def evidence_entry(result, code)
    result.evidence.find { |entry| entry["code"] == code }
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

  def expect_detected_store(result, store)
    expect(result).to have_attributes(store: store, store_confidence: "high")
    expect(result.detection.store).to eq(store)
    expect(result.source_document.store).to eq(store)
    expect(result.evidence).to include(
      a_hash_including("code" => "store_metadata_match", "store_id" => store.id)
    )
  end

  def expect_identifier_match_sources(result)
    expect(store_match_sources(result)).to include(
      "store.identifiers.receipt_store_codes",
      "store.identifiers.legal_entities",
      "store.identifiers.detection_hints.channel_markers",
      "store.identifiers.private_detection_hints.cashier_names"
    )
  end

  def expect_parser_conflict(result, explicit_format:, detected_format:)
    expect(evidence_entry(result, "explicit_parser_format_conflict")).to include(
      "explicit_parser_format" => explicit_format,
      "detected_parser_formats" => [ detected_format ]
    )
  end

  def expect_store_conflict(result, explicit_store:, detected_store:)
    expect(evidence_entry(result, "explicit_store_conflict")).to include(
      "explicit_store_id" => explicit_store.id,
      "detected_store_ids" => [ detected_store.id ]
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

  def expect_detected_parser_marker(result, parser_format:, marker:)
    expect_detected_parser_format(result, parser_format)
    expect(result.evidence).to include(
      a_hash_including(
        "code" => "parser_format_marker",
        "parser_format" => parser_format,
        "marker" => marker
      )
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
    expect(evidence_codes(result)).to contain_exactly("parser_format_not_detected", "store_not_detected")
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

  def detector_identifier_store
    create(:store,
      identifiers: {
        "receipt_store_codes" => [ "95191" ],
        "legal_entities" => [ "PRIVATE ENTITY" ],
        "detection_hints" => { "channel_markers" => [ "HEADER MARKER" ] },
        "private_detection_hints" => { "cashier_names" => [ "PRIVATE CASHIER" ] }
      }
    )
  end

  parser_fixture_examples.each do |parser_format, filename|
    it "detects #{parser_format} from extracted text markers" do
      result = call_service(text_extraction_for(fixture_text(filename)))

      expect(result).to be_classified
      expect_detected_parser_format(result, parser_format)
      expect(result.detection.parser_confidence).to eq("high")
    end
  end

  parser_marker_examples.each do |parser_format, markers|
    markers.each do |marker, text|
      it "detects #{parser_format} from the #{marker} marker" do
        result = call_service(text_extraction_for(text))

        expect(result).to be_classified
        expect_detected_parser_marker(result, parser_format: parser_format, marker: marker)
      end
    end
  end

  it "detects auchan.invoice.v1 from invoice layout markers" do
    pending("source detection rules for auchan.invoice.v1 are implemented in OpenSpec task 4.3")

    result = call_service(text_extraction_for(auchan_invoice_marker_text))

    expect(result).to be_classified
    expect_detected_parser_marker(
      result,
      parser_format: "auchan.invoice.v1",
      marker: "auchan_invoice_layout"
    )
  end

  it "persists a classified detection from explicit source document fields" do
    text_extraction = create(:text_extraction, text: "NO SOURCE MARKERS")
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

  it "keeps an explicit parser format while recording confirming detector evidence" do
    source_document = source_document_with_explicit_parser(leclerc_web_format)
    text_extraction = text_extraction_for(fixture_text("leclerc_web_v1_drive.txt"), source_document: source_document)

    result = call_service(text_extraction)

    expect(result).to have_attributes(parser_format: leclerc_web_format, parser_confidence: "manual")
    expect(result.source_document).to be_parser_format_leclerc_web_v1
    expect(evidence_codes(result)).to include("parser_format_marker")
    expect(evidence_entry(result, "explicit_parser_format_conflict")).to be_nil
  end

  it "keeps an explicit parser format while recording detector conflicts" do
    source_document = source_document_with_explicit_parser(leclerc_paper_format)
    text_extraction = text_extraction_for(fixture_text("u_paper_v2_single_payment.txt"), source_document: source_document)

    result = call_service(text_extraction)

    expect(result).to have_attributes(parser_format: leclerc_paper_format, parser_confidence: "manual")
    expect(result.source_document).to be_parser_format_leclerc_paper_v1
    expect_parser_conflict(result, explicit_format: leclerc_paper_format, detected_format: "u.paper.v2")
  end

  it "detects a store from receipt header patterns" do
    store = create(:store, identifiers: header_pattern_identifiers)
    text_extraction = text_extraction_for("PRIVATE HEADER", source_document: source_document_with_parser_hint)

    result = call_service(text_extraction)

    expect(result).to be_classified
    expect_detected_store(result, store)
    expect(evidence_codes(result)).to include("store_default_parser_format")
  end

  it "detects a store from detector-friendly identifier values" do
    store = detector_identifier_store
    text_extraction = text_extraction_for(identifier_match_text, source_document: source_document_with_parser_hint)

    result = call_service(text_extraction)

    expect_detected_store(result, store)
    expect_identifier_match_sources(result)
  end

  it "detects a store from its location name" do
    store = create(:store, location_name: "Downtown Market")
    text_extraction = text_extraction_for("Receipt DOWNTOWN MARKET", source_document: source_document_with_parser_hint)

    result = call_service(text_extraction)

    expect_detected_store(result, store)
    expect(store_match_sources(result)).to include("store.location_name")
  end

  it "uses parser-format channel narrowing for retail brand alias matches" do
    brand = create(:retail_brand, aliases: [ "Retailer Web" ])
    drive_store = create(:store, retail_brand: brand, channel: "drive")
    create(:store, retail_brand: brand, channel: "physical")
    text_extraction = text_extraction_for("Retailer Web", source_document: source_document_with_parser_hint(leclerc_web_format))

    result = call_service(text_extraction)

    expect_detected_store(result, drive_store)
    expect(store_match_sources(result)).to include("retail_brand.aliases")
  end

  it "prefers one store-specific match over generic brand matches" do
    store, text_extraction = generic_brand_with_specific_store_context

    result = call_service(text_extraction)

    expect_detected_store(result, store)
    expect(store_match_sources(result)).to include("retail_brand.aliases", "store.identifiers.receipt_store_codes")
  end

  it "blocks store selection when multiple stores remain plausible" do
    brand = create(:retail_brand, aliases: [ "Retailer Same" ])
    stores = create_list(:store, 2, retail_brand: brand, channel: "physical")
    text_extraction = text_extraction_for("Retailer Same", source_document: source_document_with_parser_hint)

    result = call_service(text_extraction)

    expect(result).to be_needs_classification
    expect(result).to have_attributes(store: nil, store_confidence: "none")
    expect(evidence_codes(result)).to include("store_ambiguous")
    expect(evidence_entry(result, "store_ambiguous")["store_ids"]).to match_array(stores.map(&:id))
  end

  it "keeps an explicit store while recording detector conflicts" do
    explicit_store = create(:store)
    detected_store = create(:store, identifiers: header_pattern_identifiers)
    source_document = source_document_with_explicit_store(explicit_store)
    text_extraction = text_extraction_for("PRIVATE HEADER", source_document: source_document)

    result = call_service(text_extraction)

    expect(result).to have_attributes(store: explicit_store, store_confidence: "manual")
    expect(result.source_document.store).to eq(explicit_store)
    expect_store_conflict(result, explicit_store: explicit_store, detected_store: detected_store)
  end

  it "keeps explicit source fields while recording parser and store conflicts" do
    explicit_store, detected_store, text_extraction = combined_conflict_context

    result = call_service(text_extraction)

    expect(result).to have_attributes(parser_format: leclerc_paper_format, store: explicit_store)
    expect_parser_conflict(result, explicit_format: leclerc_paper_format, detected_format: "u.paper.v2")
    expect_store_conflict(result, explicit_store: explicit_store, detected_store: detected_store)
  end

  it "keeps a detected parser format when store classification is still missing" do
    source_document = create(:source_document, :pending_classification)
    text_extraction = text_extraction_for("CB Web Drive", source_document: source_document)

    result = call_service(text_extraction)

    expect(result).to be_needs_classification
    expect_detected_parser_format(result, "leclerc.web.v1")
    expect(result.store).to be_nil
    expect(evidence_codes(result)).to include("store_not_detected")
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

  def header_pattern_identifiers
    {
      "default_parser_format" => leclerc_paper_format,
      "receipt_header_patterns" => [ "PRIVATE HEADER" ]
    }
  end

  def identifier_match_text
    "Magasin 95191\nPRIVATE ENTITY\nHEADER MARKER\nPRIVATE CASHIER"
  end

  def auchan_invoice_marker_text
    <<~TEXT
      Auchan
      Votre facture
      Facture éditée le : 03/02/2026
      Date de commande : 01/02/2026
      Référence Caractéristiques produit Qte. Prix total Net (TTC) €
      Mode de paiement
      CARTE BANCAIRE 10,00
    TEXT
  end

  def combined_conflict_context
    explicit_store = create(:store)
    detected_store = create(:store, identifiers: header_pattern_identifiers)
    source_document = source_document_with_explicit_store(explicit_store)
    text = "#{fixture_text('u_paper_v2_single_payment.txt')}\nPRIVATE HEADER"

    [ explicit_store, detected_store, text_extraction_for(text, source_document: source_document) ]
  end

  def generic_brand_with_specific_store_context
    brand = create(:retail_brand, aliases: [ "Retailer Same" ])
    store = create(
      :store,
      retail_brand: brand,
      channel: "physical",
      identifiers: { "receipt_store_codes" => [ "95191" ] }
    )
    create(:store, retail_brand: brand, channel: "physical")
    text_extraction = text_extraction_for("Retailer Same\nMagasin 95191", source_document: source_document_with_parser_hint)

    [ store, text_extraction ]
  end
end
