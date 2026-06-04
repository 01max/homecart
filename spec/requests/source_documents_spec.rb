require "rails_helper"
require "digest"

RSpec.describe "Source documents", type: :request do
  let(:retail_brand) { create(:retail_brand, slug: "leclerc").tap { |brand| brand.update!(name: "E.Leclerc") } }
  let(:store) { create(:store, retail_brand: retail_brand, location_name: "Villeneuve sur Lot", channel: "physical") }
  let(:auchan_brand) { create(:retail_brand, slug: "auchan").tap { |brand| brand.update!(name: "Auchan") } }
  let(:u_brand) { create(:retail_brand, slug: "magasins-u").tap { |brand| brand.update!(name: "Magasins U") } }
  let(:fixture_path) { Rails.root.join("spec/fixtures/files/receipt_text.pdf") }

  before do
    allow(Receipt::ProcessSourceDocumentJob).to receive(:perform_later)
  end

  def upload_file(content_type: "application/pdf")
    Rack::Test::UploadedFile.new(fixture_path, content_type)
  end

  def post_upload(params)
    post source_documents_path, params: { source_document: params }
  end

  def expect_upload_form
    expected_content = [
      I18n.t("source_documents.new.file_label"),
      'data-controller="parser-format-suggestion"',
      "E.Leclerc — Villeneuve sur Lot (physical)",
      "auchan.paper.v1",
      "leclerc.paper.v1",
      "leclerc.paper.v2",
      "leclerc.web.v1",
      "u.paper.v1",
      "u.paper.v2"
    ]

    expect(response.body).to include(*expected_content)
  end

  def option_for(label)
    Nokogiri::HTML(response.body).css("option").find { |option| option.text == label }
  end

  def create_parser_hint_stores
    store
    create(:store, retail_brand: auchan_brand, location_name: "Villeneuve sur Lot", channel: "physical")
    create(:store, retail_brand: retail_brand, location_name: "PARISDIF", channel: "drive")
    create(:store, retail_brand: u_brand, location_name: "Pujols", channel: "physical")
    create(:store,
      retail_brand: retail_brand,
      location_name: "Legacy override",
      channel: "physical",
      identifiers: { "default_parser_format" => "leclerc.paper.v1" }
    )
  end

  def create_unknown_parser_hint_store
    brand = RetailBrand.find_or_create_by!(slug: "retailer-a") do |retail_brand|
      retail_brand.name = "Retailer A"
      retail_brand.aliases = []
    end

    Store.find_or_create_by!(
      retail_brand: brand,
      location_name: "Location 01",
      channel: "physical"
    )
  end

  def expect_option_default(label, parser_format)
    expect(option_for(label)["data-default-parser-format"]).to eq(parser_format)
  end

  def expect_option_without_default(label)
    expect(option_for(label)["data-default-parser-format"]).to be_nil
  end

  def expect_known_parser_format_defaults
    expect_option_default("Auchan — Villeneuve sur Lot (physical)", "auchan.paper.v1")
    expect_option_default("E.Leclerc — Villeneuve sur Lot (physical)", "leclerc.paper.v2")
    expect_option_default("E.Leclerc — PARISDIF (drive)", "leclerc.web.v1")
    expect_option_default("Magasins U — Pujols (physical)", "u.paper.v2")
    expect_option_default("E.Leclerc — Legacy override (physical)", "leclerc.paper.v1")
  end

  def expect_created_source_document(source_document)
    expect(source_document).to have_attributes(store: store)
    expect(source_document).to be_parser_format_leclerc_paper_v1
    expect(source_document.content_hash).to eq(Digest::SHA256.file(fixture_path).hexdigest)
    expect(source_document.original_file).to be_attached
  end

  def attach_original_file(source_document, path: fixture_path, content_type: "application/pdf")
    File.open(path) do |file|
      source_document.original_file.attach(io: file, filename: File.basename(path), content_type: content_type)
    end
  end

  def create_extraction(source_document:, text:, ran_at:, success: true, error_message: nil)
    create(
      :text_extraction,
      source_document: source_document,
      text: success ? text : "",
      ran_at: ran_at,
      success: success,
      error_message: error_message
    )
  end

  def expect_source_document_show(receipt)
    expect(response.body).to include("receipt_text.pdf", "<iframe", "latest extraction")
    expect(response.body).not_to include("older extraction")
    expect(response.body).to include(%(href="/receipts#receipt_#{receipt.id}"))
  end

  it "renders a single upload form with store and parser format dropdowns" do
    store

    get new_source_document_path

    expect(response).to have_http_status(:ok)
    expect_upload_form
  end

  it "renders default parser format hints for the upload form controller" do
    create_parser_hint_stores
    create_unknown_parser_hint_store

    get new_source_document_path

    expect(response).to have_http_status(:ok)
    expect_known_parser_format_defaults
    expect_option_without_default("Retailer A — Location 01 (physical)")
  end

  it "creates a source document, attaches the upload, and enqueues processing" do
    expect do
      post_upload(file: upload_file, store_id: store.id, parser_format: "leclerc.paper.v1")
    end.to change(SourceDocument, :count).by(1)

    source_document = SourceDocument.last
    expect_created_source_document(source_document)
    expect(Receipt::ProcessSourceDocumentJob).to have_received(:perform_later).with(source_document)
    expect(response).to redirect_to(source_document_path(source_document))
    expect(flash[:notice]).to eq(I18n.t("source_documents.create.success"))
  end

  it "redirects duplicate uploads to the existing source document without enqueueing processing" do
    existing_source_document = create(:source_document, content_hash: Digest::SHA256.file(fixture_path).hexdigest)

    expect do
      post_upload(file: upload_file, store_id: store.id, parser_format: "leclerc.paper.v1")
    end.not_to change(SourceDocument, :count)

    expect(response).to redirect_to(source_document_path(existing_source_document))
    expect(flash[:notice]).to eq(I18n.t("source_documents.create.duplicate"))
    expect(Receipt::ProcessSourceDocumentJob).not_to have_received(:perform_later)
  end

  it "rejects uploads without a store or parser format before creating a source document" do
    expect do
      post_upload(file: upload_file)
    end.not_to change(SourceDocument, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(I18n.t("source_documents.create.errors.missing_store"))
    expect(response.body).to include(I18n.t("source_documents.create.errors.missing_parser_format"))
    expect(Receipt::ProcessSourceDocumentJob).not_to have_received(:perform_later)
  end

  it "rejects unsupported uploads before creating a source document" do
    expect do
      post_upload(file: upload_file(content_type: "text/plain"), store_id: store.id, parser_format: "leclerc.paper.v1")
    end.not_to change(SourceDocument, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("unsupported MIME type: text/plain")
    expect(response.body).to include("application/pdf, image/png, image/jpeg")
    expect(Receipt::ProcessSourceDocumentJob).not_to have_received(:perform_later)
  end

  it "shows the original file preview, latest extraction, and associated receipt link" do
    source_document = create(:source_document, store: store)
    attach_original_file(source_document)
    create_extraction(source_document: source_document, text: "older extraction", ran_at: 2.hours.ago)
    latest_extraction = create_extraction(source_document: source_document, text: "latest extraction", ran_at: 1.hour.ago)
    receipt = create(:receipt, store: store, source_document: source_document, text_extraction: latest_extraction)

    get source_document_path(source_document)

    expect(response).to have_http_status(:ok)
    expect_source_document_show(receipt)
  end

  it "shows empty states before extraction and parsing complete" do
    source_document = create(:source_document, store: store)

    get source_document_path(source_document)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("source_documents.show.preview.missing_file"))
    expect(response.body).to include(I18n.t("source_documents.show.latest_extraction.empty"))
    expect(response.body).to include(I18n.t("source_documents.show.receipt.empty"))
  end
end
