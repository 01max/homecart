require "rails_helper"

RSpec.describe ReceiptIngestion::ManualClassifySourceDocumentService do
  let(:parse_job_class) { class_spy(Receipt::ParseJob) }

  def call_service(source_document:, store:, parser_format: "u.paper.v2")
    described_class.call(
      source_document: source_document,
      store: store,
      parser_format: parser_format,
      parse_job_class: parse_job_class
    )
  end

  def classification_context(parser_format: "u.paper.v2")
    source_document = create(:source_document, :needs_classification)
    older_extraction = create(:text_extraction, source_document: source_document, ran_at: 1.day.ago)
    latest_extraction = create(:text_extraction, source_document: source_document, ran_at: 1.hour.ago)
    store = create(:store)

    { source_document: source_document, older_extraction: older_extraction, latest_extraction: latest_extraction, store: store, parser_format: parser_format }
  end

  def expect_manual_classification(result, context)
    expect(result.source_document).to be_classified
    expect(result.source_document).to have_attributes(store: context.fetch(:store))
    expect(result.source_document.parser_format_before_type_cast).to eq(context.fetch(:parser_format))
    expect(result.text_extraction).to eq(context.fetch(:latest_extraction))
    expect_manual_detection(result.detection, context)
  end

  def expect_manual_detection(detection, context)
    expect(detection).to have_attributes(
      source_document: context.fetch(:source_document),
      text_extraction: context.fetch(:latest_extraction),
      store: context.fetch(:store),
      parser_confidence: "manual",
      store_confidence: "manual",
      evidence: [ { "code" => "manual_classification", "store_id" => context.fetch(:store).id, "parser_format" => context.fetch(:parser_format) } ]
    )
    expect(detection).to be_parser_format_u_paper_v2
    expect(detection).to be_classified
  end

  def expect_parse_enqueued_for_latest_extraction(context)
    expect(parse_job_class).to have_received(:perform_later).with(context.fetch(:latest_extraction).id)
    expect(parse_job_class).not_to have_received(:perform_later).with(context.fetch(:older_extraction).id)
  end

  it "records a manual detection and marks the source document classified" do
    context = classification_context

    result = call_service(source_document: context.fetch(:source_document), store: context.fetch(:store))

    expect_manual_classification(result, context)
    expect_parse_enqueued_for_latest_extraction(context)
  end

  it "normalizes parser format enum keys before persisting the manual classification" do
    context = classification_context(parser_format: "leclerc.paper.v1")

    result = call_service(source_document: context.fetch(:source_document), store: context.fetch(:store), parser_format: :leclerc_paper_v1)

    expect(result.source_document).to be_parser_format_leclerc_paper_v1
    expect(result.detection).to be_parser_format_leclerc_paper_v1
    expect(result.detection.evidence.sole["parser_format"]).to eq("leclerc.paper.v1")
  end

  it "raises without changing classification when no successful text extraction exists" do
    source_document = create(:source_document, :needs_classification)
    create(:text_extraction, :failed, source_document: source_document)

    expect { call_service(source_document: source_document, store: create(:store)) }
      .to raise_error(described_class::MissingSuccessfulTextExtractionError, /no successful text extraction/)

    expect(source_document.reload).to be_needs_classification
    expect(SourceDocumentDetection.count).to eq(0)
    expect(parse_job_class).not_to have_received(:perform_later)
  end
end
