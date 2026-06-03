require "rails_helper"
require "digest"

RSpec.describe "Source documents", type: :request do
  let(:retail_brand) { create_retail_brand(slug: "leclerc").tap { |brand| brand.update!(name: "E.Leclerc") } }
  let(:store) { create_store(retail_brand: retail_brand, location_name: "Villeneuve sur Lot", channel: "physical") }
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

  def expect_created_source_document(source_document)
    expect(source_document).to have_attributes(store: store)
    expect(source_document).to be_parser_format_leclerc_paper_v1
    expect(source_document.content_hash).to eq(Digest::SHA256.file(fixture_path).hexdigest)
    expect(source_document.original_file).to be_attached
  end

  it "renders a single upload form with store and parser format dropdowns" do
    store

    get new_source_document_path

    expect(response).to have_http_status(:ok)
    expect_upload_form
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
    existing_source_document = create_source_document(content_hash: Digest::SHA256.file(fixture_path).hexdigest)

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
end
