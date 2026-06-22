require "rails_helper"
require Rails.root.join("db/migrate/20260620091000_add_source_detection_status_to_source_documents")

RSpec.describe AddSourceDetectionStatusToSourceDocuments do
  def run_backfill
    migration = described_class.new

    migration.suppress_messages do
      migration.send(:backfill_manual_detection_records)
    end
  end

  it "backfills manual detection records from the latest successful text extraction" do
    source_document, latest_extraction = create_backfill_source_document

    run_backfill

    expect_backfilled_detection(source_document, latest_extraction)
  end

  it "does not backfill a detection without a successful text extraction" do
    source_document = create(:source_document)
    create(:text_extraction, :failed, source_document: source_document)

    run_backfill

    expect(source_document.source_document_detections).to be_empty
  end

  def create_backfill_source_document
    source_document = create(:source_document, parser_format: "u.paper.v2")
    create(:text_extraction, source_document: source_document, ran_at: 2.days.ago)
    create(:text_extraction, :failed, source_document: source_document, ran_at: 1.day.ago)
    latest_extraction = create(:text_extraction, source_document: source_document, ran_at: 1.hour.ago)

    [ source_document, latest_extraction ]
  end

  def expect_backfilled_detection(source_document, latest_extraction)
    detection = source_document.source_document_detections.sole
    expect(detection).to have_attributes(
      source_document: source_document,
      text_extraction: latest_extraction,
      store: source_document.store,
      status: "classified",
      parser_confidence: "manual",
      store_confidence: "manual",
      evidence: [ { "code" => "manual_backfill", "migration" => "20260620091000" } ]
    )
    expect(detection.parser_format_before_type_cast).to eq("u.paper.v2")
  end
end
