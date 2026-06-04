require "rails_helper"

RSpec.describe "Source document upload", type: :system do
  let(:retail_brand) { create_retail_brand(slug: "auchan").tap { |brand| brand.update!(name: "Auchan") } }
  let(:store) { create_store(retail_brand: retail_brand, location_name: "Villeneuve sur Lot", channel: "physical") }
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

  def upload_receipt
    visit new_source_document_path
    attach_file I18n.t("source_documents.new.file_label"), fixture_path
    select "Auchan — Villeneuve sur Lot (physical)", from: I18n.t("source_documents.new.store_label")
    select "auchan.paper.v1", from: I18n.t("source_documents.new.parser_format_label")
    click_button I18n.t("source_documents.new.submit")
  end

  def expect_source_document_to_be_processed
    expect(page).to have_content(I18n.t("source_documents.create.success"))
    expect(page).to have_content(I18n.t("source_documents.show.processing.states.complete"))
    expect(TextExtraction.last).to have_attributes(success: true, text: extracted_text)
    expect(Receipt.last).to have_attributes(parser_status: "parsed", total_cents: 500)
  end

  def expect_parsed_receipt_to_be_listed
    visit receipts_path

    expect(page).to have_content("Auchan — Villeneuve sur Lot (physical)")
    expect(page).to have_content(I18n.t("receipts.parser_statuses.parsed"))
    expect(page).to have_content("5,00 €")
  end

  it "uploads an Auchan PNG, extracts text, parses a receipt, and shows it in the listing" do
    store

    perform_enqueued_jobs { upload_receipt }

    expect_source_document_to_be_processed
    expect_parsed_receipt_to_be_listed
  end
end
