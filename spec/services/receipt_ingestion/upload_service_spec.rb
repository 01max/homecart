require "rails_helper"
require "digest"
require "tempfile"

RSpec.describe ReceiptIngestion::UploadService do
  let(:store) { create_store }
  let(:job_class) { class_spy(Receipt::ProcessSourceDocumentJob) }
  let(:broadcaster) { class_spy(ReceiptIngestion::BroadcastProcessingStatusService) }

  after do
    uploaded_files.each do |file|
      file.close
      file.unlink
    end
  end

  def uploaded_files
    @uploaded_files ||= []
  end

  def uploaded_file(content: "receipt bytes", content_type: "application/pdf", filename: "receipt.pdf")
    Tempfile.new("receipt").tap do |file|
      file.binmode
      file.write(content)
      file.rewind
      file.define_singleton_method(:content_type) { content_type }
      file.define_singleton_method(:original_filename) { filename }
      uploaded_files << file
    end
  end

  def expect_uploaded_source_document(source_document, content:)
    expect(source_document).to have_attributes(store: store, content_hash: Digest::SHA256.hexdigest(content))
    expect(source_document).to be_mime_type_pdf
    expect(source_document).to be_parser_format_leclerc_paper_v1
    expect(source_document.original_file).to be_attached
  end

  def call_service(file)
    described_class.call(
      file: file,
      store: store,
      parser_format: "leclerc.paper.v1",
      job_class: job_class,
      broadcaster: broadcaster
    )
  end

  def expect_queued_broadcast(source_document)
    expect(broadcaster).to have_received(:call).with(
      source_document: source_document,
      extraction_state: "queued",
      parsing_state: "waiting"
    )
  end

  it "creates a source document, stores the original file, and enqueues source document processing" do
    content = "new receipt"
    file = uploaded_file(content: content)

    result = call_service(file)
    source_document = result.source_document

    expect(result.duplicate).to be(false)
    expect_uploaded_source_document(source_document, content: content)
    expect(job_class).to have_received(:perform_later).with(source_document)
    expect_queued_broadcast(source_document)
  end

  it "returns an existing source document for duplicate content without enqueueing processing" do
    existing_source_document = create_source_document(content_hash: Digest::SHA256.hexdigest("same receipt"))
    file = uploaded_file(content: "same receipt")

    result = call_service(file)

    expect(result.source_document).to eq(existing_source_document)
    expect(result.duplicate).to be(true)
    expect(SourceDocument.count).to eq(1)
    expect(job_class).not_to have_received(:perform_later)
    expect(broadcaster).not_to have_received(:call)
  end

  it "rejects unsupported MIME types before creating a source document" do
    file = uploaded_file(content_type: "text/plain", filename: "receipt.txt")

    expect do
      described_class.call(file: file, store: store, parser_format: "leclerc.paper.v1", job_class: job_class)
    end.to raise_error(described_class::UnsupportedMimeTypeError, /supported types: application\/pdf, image\/png, image\/jpeg/)

    expect(SourceDocument.count).to eq(0)
  end
end
