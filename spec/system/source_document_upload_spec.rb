require "rails_helper"

RSpec.describe "Source document upload", type: :system do
  let(:retail_brand) { catalog_brand(slug: "auchan", name: "Auchan") }
  let(:store) { catalog_store(retail_brand: retail_brand, location_name: "Villeneuve sur Lot", channel: "physical") }
  let(:auto_detectable_store) do
    catalog_store(
      retail_brand: retail_brand,
      location_name: "Villeneuve sur Lot",
      channel: "physical",
      identifiers: { "receipt_header_patterns" => [ "ANONYMIZED CITY" ] }
    )
  end
  let(:fixture_path) { Rails.root.join("spec/fixtures/files/receipt_image.png") }
  let(:extracted_text) { Rails.root.join("spec/fixtures/files/parser/auchan_paper_v1_cashier.txt").read }

  before do
    stub_image_extraction
  end

  def stub_image_extraction
    result = ReceiptIngestion::ExtractImageWithTesseractService::ExtractionResult.new(
      text: extracted_text,
      engine: "tesseract-test-fra-psm6"
    )
    allow(ReceiptIngestion::ExtractImageWithTesseractService).to receive(:call).and_return(result)
  end

  def catalog_brand(slug:, name:)
    RetailBrand.find_or_initialize_by(slug: slug).tap do |brand|
      brand.name = name
      brand.aliases ||= []
      brand.save!
    end
  end

  def catalog_store(retail_brand:, location_name:, channel:, identifiers: {})
    Store.find_or_initialize_by(
      retail_brand: retail_brand,
      location_name: location_name,
      channel: channel
    ).tap do |store|
      store.identifiers = identifiers
      store.save!
    end
  end

  def store_option_label(store)
    I18n.t(
      "source_documents.form.store_option",
      brand: store.retail_brand.name,
      location: store.location_name,
      channel: store.channel
    )
  end

  def upload_receipt(store_hint: nil, parser_format: nil)
    visit new_source_document_path
    attach_file I18n.t("source_documents.new.file_label"), fixture_path
    select store_option_label(store_hint), from: I18n.t("source_documents.new.store_label") if store_hint
    select parser_format, from: I18n.t("source_documents.new.parser_format_label") if parser_format
    click_button I18n.t("source_documents.new.submit")
  end

  def manually_classify_source_document(store:)
    select store_option_label(store), from: I18n.t("source_documents.show.classification.manual.store_label")
    select "auchan.paper.v1", from: I18n.t("source_documents.show.classification.manual.parser_format_label")
    click_button I18n.t("source_documents.show.classification.manual.submit")
  end

  def expect_upload_to_be_processed(store:)
    source_document = SourceDocument.last

    expect(page).to have_content(I18n.t("source_documents.create.success"))
    expect_source_document_to_be_processed(source_document, store: store)
  end

  def expect_source_document_to_be_processed(source_document = SourceDocument.last, store:)
    expect(page).to have_content(I18n.t("source_documents.show.processing.states.complete"))
    expect(page).to have_content(store_option_label(store))
    expect(page).to have_content("auchan.paper.v1")
    expect(source_document.reload).to have_attributes(store: store, source_detection_status: "classified")
    expect(source_document).to be_parser_format_auchan_paper_v1
    expect(TextExtraction.last).to have_attributes(success: true, text: extracted_text)
    expect(Receipt.last).to have_attributes(
      store: store,
      source_document: source_document,
      parser_status: "parsed",
      total_cents: 500
    )
  end

  def expect_parsed_receipt_to_be_listed(store:)
    visit receipts_path

    expect(page).to have_content(store_option_label(store))
    expect(page).to have_content(I18n.t("receipts.parser_statuses.parsed"))
    expect(page).to have_content("5,00 €")
  end

  def expect_manual_classification_required
    source_document = SourceDocument.last

    expect(source_document.reload).to be_needs_classification
    expect(source_document).to be_parser_format_auchan_paper_v1
    expect(page).to have_content(I18n.t("source_documents.show.processing.states.needs_classification"))
    expect(page).to have_content(I18n.t("source_documents.show.classification.manual.heading"))
    expect(page).to have_content(I18n.t("source_documents.show.receipt.empty"))
    expect(Receipt.count).to eq(0)
  end

  def latest_source_document_detection
    SourceDocumentDetection.order(created_at: :desc, id: :desc).first
  end

  it "uploads an Auchan PNG with hints, extracts text, parses a receipt, and shows it in the listing" do
    store

    perform_enqueued_jobs { upload_receipt(store_hint: store, parser_format: "auchan.paper.v1") }

    expect_upload_to_be_processed(store: store)
    expect(latest_source_document_detection).to have_attributes(parser_confidence: "manual", store_confidence: "manual")
    expect_parsed_receipt_to_be_listed(store: store)
  end

  it "uploads an Auchan PNG without hints and parses after automatic source classification" do
    auto_detectable_store

    perform_enqueued_jobs { upload_receipt }

    expect_upload_to_be_processed(store: auto_detectable_store)
    expect(latest_source_document_detection).to have_attributes(parser_confidence: "high", store_confidence: "high")
    expect_parsed_receipt_to_be_listed(store: auto_detectable_store)
  end

  it "uploads without hints, waits for manual classification, and resumes parsing from the source page" do
    store

    perform_enqueued_jobs { upload_receipt }

    expect_manual_classification_required

    perform_enqueued_jobs { manually_classify_source_document(store: store) }

    expect(page).to have_content(I18n.t("source_documents.classify.success"))
    expect_source_document_to_be_processed(store: store)
    expect(latest_source_document_detection).to have_attributes(parser_confidence: "manual", store_confidence: "manual")
  end
end
