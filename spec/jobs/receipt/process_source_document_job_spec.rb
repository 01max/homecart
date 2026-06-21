require "rails_helper"

RSpec.describe Receipt::ProcessSourceDocumentJob do
  let(:broadcaster) { class_spy(ReceiptIngestion::BroadcastProcessingStatusService) }
  let(:parse_job_class) { class_spy(Receipt::ParseJob) }
  let(:source_detector) { class_spy(ReceiptIngestion::DetectSourceDocumentService) }

  def stub_extraction(source_document, success: true)
    factory_arguments = success ? [ :text_extraction ] : [ :text_extraction, :failed ]

    create(*factory_arguments, source_document: source_document).tap do |text_extraction|
      allow(ReceiptIngestion::ExtractTextService).to receive(:call).and_return(text_extraction)
    end
  end

  def perform_job(source_document)
    described_class.perform_now(
      source_document,
      broadcaster: broadcaster,
      source_detector: source_detector,
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

  it "does not enqueue parsing when source detection needs classification" do
    source_document = create(:source_document, :needs_classification)
    text_extraction = stub_extraction(source_document)
    stub_detection(source_document, classified: false)

    perform_job(source_document)

    expect(parse_job_class).not_to have_received(:perform_later)
    expect_finished_broadcast(source_document, text_extraction, extraction_state: "complete", parsing_state: "blocked")
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
