require "rails_helper"
require "digest"

RSpec.describe "Source documents", type: :request do
  let(:retail_brand) { catalog_brand(slug: "leclerc", name: "E.Leclerc") }
  let(:store) { catalog_store(retail_brand: retail_brand, location_name: "Villeneuve sur Lot", channel: "physical") }
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

  def expect_upload_form
    expected_content = [
      I18n.t("source_documents.new.file_label"),
      I18n.t("source_documents.new.workflow.heading"),
      I18n.t("source_documents.new.store_prompt"),
      I18n.t("source_documents.new.store_hint"),
      I18n.t("source_documents.new.parser_format_prompt"),
      I18n.t("source_documents.new.parser_format_hint"),
      I18n.t("source_documents.new.workflow.processing_value"),
      "hc-filter-block",
      "E.Leclerc — Villeneuve sur Lot (physical)",
      "auchan.paper.v1",
      "leclerc.paper.v1",
      "leclerc.paper.v2",
      "leclerc.web.v1",
      "u.paper.v1",
      "u.paper.v2"
    ]

    expect(response.body).to include(*expected_content)
    expect(response.body).not_to include("parser-format-suggestion", "data-default-parser-format")
  end

  def option_for(label)
    Nokogiri::HTML(response.body).css("option").find { |option| option.text == label }
  end

  def store_with_default_parser_format
    catalog_store(
      retail_brand: retail_brand,
      location_name: "Legacy override",
      channel: "physical",
      identifiers: { "default_parser_format" => "leclerc.paper.v1" }
    )
  end

  def expect_created_source_document(source_document)
    expect(source_document).to have_attributes(store: store)
    expect(source_document).to be_pending
    expect(source_document).to be_parser_format_leclerc_paper_v1
    expect(source_document.content_hash).to eq(Digest::SHA256.file(fixture_path).hexdigest)
    expect(source_document.original_file).to be_attached
  end

  def expect_pending_source_document(source_document)
    expect(source_document).to have_attributes(store: nil, parser_format: nil)
    expect(source_document).to be_pending
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
    expect(response.body).to include("hc-page-toolbar", "hc-evidence-block", "hc-detail-block")
    expect(response.body).not_to include("older extraction")
    expect(response.body).to include(%(href="/receipts/#{receipt.id}"))
  end

  def create_showable_source_document
    source_document = create(:source_document, store: store)
    attach_original_file(source_document)
    create_extraction(source_document: source_document, text: "older extraction", ran_at: 2.hours.ago)
    latest_extraction = create_extraction(source_document: source_document, text: "latest extraction", ran_at: 1.hour.ago)
    receipt = create(:receipt, store: store, source_document: source_document, text_extraction: latest_extraction)

    [ source_document, receipt ]
  end

  def expect_source_document_evidence_to_be_read_only
    expect(response.body).not_to include(%(name="source_document[original_file]"))
    expect(response.body).not_to include(%(name="source_document[content_hash]"))
    expect(response.body).not_to include(%(name="source_document[mime_type]"))
    expect(response.body).not_to include(%(name="source_document[ingested_at]"))
    expect(response.body).not_to include(%(name="text_extraction[engine]"))
    expect(response.body).not_to include(%(name="text_extraction[text]"))
    expect(response.body).not_to include(%(name="text_extraction[ran_at]"))
    expect(response.body).not_to include(%(name="text_extraction[success]"))
    expect(response.body).not_to include(%(name="text_extraction[error_message]"))
  end

  def dom_id(record, prefix)
    ActionView::RecordIdentifier.dom_id(record, prefix)
  end

  def expect_status_streams_for(source_document)
    expect(response.body).to include(
      %(target="#{dom_id(source_document, :processing_status)}"),
      %(target="#{dom_id(source_document, :latest_text_extraction)}"),
      %(target="#{dom_id(source_document, :receipt_summary)}")
    )
  end

  def get_status_stream(source_document)
    get status_source_document_path(source_document, format: :turbo_stream)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
    expect_status_streams_for(source_document)
  end

  def expect_processing_state_labels(*labels, complete:)
    expect(response.body).to include(%(data-processing-complete="#{complete}"))
    labels.each do |label|
      expect(response.body).to include(label)
    end
  end

  it "renders a single upload form with store and parser format dropdowns" do
    store

    get new_source_document_path

    expect(response).to have_http_status(:ok)
    expect_upload_form
  end

  it "keeps parser format as an explicit override instead of a store-driven default" do
    store_with_default_parser_format

    get new_source_document_path

    expect(response).to have_http_status(:ok)
    expect(option_for("E.Leclerc — Legacy override (physical)")["data-default-parser-format"]).to be_nil
    expect(option_for(I18n.t("source_documents.new.parser_format_prompt"))).to be_present
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

  it "accepts uploads without a store or parser format as pending source detection" do
    expect do
      post_upload(file: upload_file)
    end.to change(SourceDocument, :count).by(1)

    source_document = SourceDocument.last
    expect_pending_source_document(source_document)
    expect(Receipt::ProcessSourceDocumentJob).to have_received(:perform_later).with(source_document)
    expect(response).to redirect_to(source_document_path(source_document))
  end

  it "rejects invalid classification hints before creating a source document" do
    expect do
      post_upload(file: upload_file, store_id: "00000000-0000-0000-0000-000000000000", parser_format: "unknown.paper.v1")
    end.not_to change(SourceDocument, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(I18n.t("source_documents.create.errors.invalid_store"))
    expect(response.body).to include(I18n.t("source_documents.create.errors.invalid_parser_format"))
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
    source_document, receipt = create_showable_source_document

    get source_document_path(source_document)

    expect(response).to have_http_status(:ok)
    expect_source_document_show(receipt)
    expect_source_document_evidence_to_be_read_only
  end

  it "shows empty states before extraction and parsing complete" do
    source_document = create(:source_document, store: store)

    get source_document_path(source_document)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("source_documents.show.preview.missing_file"))
    expect(response.body).to include(I18n.t("source_documents.show.latest_extraction.empty"))
    expect(response.body).to include(I18n.t("source_documents.show.receipt.empty"))
  end

  it "renders turbo stream status replacements for source document polling" do
    source_document = create(:source_document, store: store)

    get_status_stream(source_document)

    expect_processing_state_labels(
      I18n.t("source_documents.show.processing.states.queued"),
      I18n.t("source_documents.show.processing.states.classified"),
      I18n.t("source_documents.show.processing.states.waiting"),
      complete: false
    )
  end

  it "renders pending source classification in processing status before extraction" do
    source_document = create(:source_document, :pending_classification)

    get_status_stream(source_document)

    expect_processing_state_labels(
      I18n.t("source_documents.show.processing.states.queued"),
      I18n.t("source_documents.show.processing.states.pending"),
      I18n.t("source_documents.show.processing.states.waiting"),
      complete: false
    )
  end

  it "renders needs-classification processing status after successful extraction" do
    source_document = create(:source_document, :needs_classification)
    create_extraction(source_document: source_document, text: "needs review", ran_at: 1.minute.ago)

    get_status_stream(source_document)

    expect_processing_state_labels(
      I18n.t("source_documents.show.processing.states.complete"),
      I18n.t("source_documents.show.processing.states.needs_classification"),
      complete: true
    )
  end
end
