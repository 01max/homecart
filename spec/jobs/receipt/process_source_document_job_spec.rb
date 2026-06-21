require "rails_helper"

RSpec.describe Receipt::ProcessSourceDocumentJob do
  let(:broadcaster) { class_spy(ReceiptIngestion::BroadcastProcessingStatusService) }
  let(:parse_job_class) { class_spy(Receipt::ParseJob) }
  let(:source_detector) { class_spy(ReceiptIngestion::DetectSourceDocumentService) }

  def stub_extraction(source_document, success: true, text: nil)
    factory_arguments = success ? [ :text_extraction ] : [ :text_extraction, :failed ]
    attributes = { source_document: source_document }
    attributes[:text] = text if text

    create(*factory_arguments, **attributes).tap do |text_extraction|
      allow(ReceiptIngestion::ExtractTextService).to receive(:call).and_return(text_extraction)
    end
  end

  def perform_job(source_document, detector: source_detector)
    described_class.perform_now(
      source_document,
      broadcaster: broadcaster,
      source_detector: detector,
      parse_job_class: parse_job_class
    )
  end

  def stub_detection(source_document, classified: true)
    detection_result = instance_double(ReceiptIngestion::DetectSourceDocumentService::Result, source_document: source_document)
    allow(detection_result).to receive(:classified?).and_return(classified)
    allow(source_detector).to receive(:call).and_return(detection_result)
    detection_result
  end

  def expect_running_broadcast(source_document)
    expect(broadcaster).to have_received(:call).with(
      source_document: source_document,
      extraction_state: "running",
      parsing_state: "waiting"
    )
  end

  def expect_finished_broadcast(source_document, text_extraction, extraction_state:, parsing_state:)
    expect(broadcaster).to have_received(:call).with(
      source_document: source_document,
      text_extraction: text_extraction,
      extraction_state: extraction_state,
      parsing_state: parsing_state
    )
  end

  def expect_real_detection_blocked_parsing(source_document, text_extraction)
    detection = SourceDocumentDetection.sole
    expect(source_document.reload).to be_needs_classification
    expect(detection).to have_attributes(source_document: source_document, text_extraction: text_extraction)
    expect(detection).to be_needs_classification
    expect(parse_job_class).not_to have_received(:perform_later)
    expect_finished_broadcast(source_document, text_extraction, extraction_state: "complete", parsing_state: "needs_classification")
  end

  it "runs on the receipt handling queue" do
    expect(described_class.queue_name).to eq("receipt_handling")
  end

  it "delegates extraction to the service" do
    source_document = create(:source_document)
    stub_extraction(source_document)
    stub_detection(source_document)

    perform_job(source_document)

    expect(ReceiptIngestion::ExtractTextService).to have_received(:call).with(source_document: source_document)
  end

  it "runs source detection for a successful text extraction" do
    source_document = create(:source_document)
    text_extraction = stub_extraction(source_document)
    stub_detection(source_document)

    perform_job(source_document)

    expect(source_detector).to have_received(:call).with(text_extraction: text_extraction)
  end

  it "enqueues parsing after successful text extraction when source detection is classified" do
    source_document = create(:source_document)
    text_extraction = stub_extraction(source_document)
    stub_detection(source_document)

    perform_job(source_document)

    expect(parse_job_class).to have_received(:perform_later).with(text_extraction.id)
    expect_finished_broadcast(source_document, text_extraction, extraction_state: "complete", parsing_state: "queued")
  end

  it "enqueues parsing after real source detection classifies the document" do
    source_document = create(:source_document, :pending_classification, store: create(:store))
    text_extraction = stub_extraction(source_document, text: "Code HT TVA TTC")

    perform_job(source_document, detector: ReceiptIngestion::DetectSourceDocumentService)

    expect(source_document.reload).to be_classified
    expect(source_document).to be_parser_format_leclerc_paper_v2
    expect(parse_job_class).to have_received(:perform_later).with(text_extraction.id)
    expect_finished_broadcast(source_document, text_extraction, extraction_state: "complete", parsing_state: "queued")
  end

  it "does not enqueue parsing when source detection needs classification" do
    source_document = create(:source_document, :needs_classification)
    text_extraction = stub_extraction(source_document)
    stub_detection(source_document, classified: false)

    perform_job(source_document)

    expect(parse_job_class).not_to have_received(:perform_later)
    expect_finished_broadcast(source_document, text_extraction, extraction_state: "complete", parsing_state: "needs_classification")
  end

  it "blocks parsing when real source detection needs manual classification" do
    source_document = create(:source_document, :pending_classification)
    text_extraction = stub_extraction(source_document, text: "Unrecognized receipt text")

    perform_job(source_document, detector: ReceiptIngestion::DetectSourceDocumentService)

    expect_real_detection_blocked_parsing(source_document, text_extraction)
  end

  it "does not enqueue parsing for a failed text extraction" do
    source_document = create(:source_document)
    text_extraction = stub_extraction(source_document, success: false)

    perform_job(source_document)

    expect(parse_job_class).not_to have_received(:perform_later)
    expect_finished_broadcast(source_document, text_extraction, extraction_state: "failed", parsing_state: "blocked")
  end

  it "does not run source detection for a failed text extraction" do
    source_document = create(:source_document)
    stub_extraction(source_document, success: false)

    perform_job(source_document)

    expect(source_detector).not_to have_received(:call)
  end

  it "broadcasts extraction running before delegating to the service" do
    source_document = create(:source_document)
    stub_extraction(source_document)
    stub_detection(source_document)

    perform_job(source_document)

    expect_running_broadcast(source_document)
  end
end
