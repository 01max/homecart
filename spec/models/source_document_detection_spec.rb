require "rails_helper"

RSpec.describe SourceDocumentDetection do
  it "belongs to its source document, text extraction, and optional store" do
    detection = create(:source_document_detection)

    expect(detection.source_document.source_document_detections).to contain_exactly(detection)
    expect(detection.text_extraction.source_document_detections).to contain_exactly(detection)
    expect(detection.store.source_document_detections).to contain_exactly(detection)
  end

  it "declares statuses and confidence levels" do
    expect(described_class.statuses.keys).to contain_exactly("classified", "needs_classification")
    expect(described_class.parser_confidences.keys).to contain_exactly("none", "low", "high", "manual")
    expect(described_class.store_confidences.keys).to contain_exactly("none", "low", "high", "manual")
  end

  it "uses the expected database enum values for status and confidence" do
    expect(enum_values("source_document_detection_status")).to eq(%w[classified needs_classification])
    expect(enum_values("source_document_detection_confidence")).to eq(%w[none low high manual])
  end

  it "uses registered parser formats" do
    expect(described_class.parser_formats.keys).to include("auchan_paper_v1", "leclerc_paper_v2", "u_paper_v1")
  end

  it "allows a needs-classification detection without selected source fields" do
    expect(create(:source_document_detection, :needs_classification)).to be_persisted
  end

  it "applies database defaults for confidence and evidence" do
    source_document = create(:source_document, :needs_classification)
    text_extraction = create(:text_extraction, source_document: source_document)

    insert_detection_with_defaults(source_document, text_extraction)

    detection = described_class.order(created_at: :desc).first
    expect(detection).to have_attributes(parser_confidence: "none", store_confidence: "none", evidence: [])
  end

  it "requires evidence to be an array" do
    detection = build(:source_document_detection, evidence: {})

    expect(detection).not_to be_valid
    expect(detection.errors.of_kind?(:evidence, :not_an_array)).to be(true)
  end

  it "enforces evidence array shape at the database level" do
    detection = create(:source_document_detection)
    quoted_id = ActiveRecord::Base.connection.quote(detection.id)
    sql = "UPDATE source_document_detections SET evidence = '{}'::jsonb WHERE id = #{quoted_id}"

    expect { execute_in_savepoint(sql) }
      .to raise_error(ActiveRecord::StatementInvalid, /source_document_detections_evidence_array/)
  end

  it "requires the text extraction to belong to the source document" do
    detection = build(:source_document_detection, text_extraction: create(:text_extraction))

    expect(detection).not_to be_valid
    expect(detection.errors.of_kind?(:text_extraction, :source_document_mismatch)).to be(true)
  end

  it "keeps parser confidence consistent with parser format" do
    without_format = build(:source_document_detection, parser_format: nil, parser_confidence: "high")
    without_confidence = build(:source_document_detection, parser_format: "leclerc.paper.v1", parser_confidence: "none")

    expect(without_format).not_to be_valid
    expect(without_format.errors.of_kind?(:parser_confidence, :must_be_none_without_parser_format)).to be(true)
    expect(without_confidence).not_to be_valid
    expect(without_confidence.errors.of_kind?(:parser_confidence, :must_not_be_none_with_parser_format)).to be(true)
  end

  it "keeps store confidence consistent with store" do
    without_store = build(:source_document_detection, store: nil, store_confidence: "high")
    without_confidence = build(:source_document_detection, store_confidence: "none")

    expect(without_store).not_to be_valid
    expect(without_store.errors.of_kind?(:store_confidence, :must_be_none_without_store)).to be(true)
    expect(without_confidence).not_to be_valid
    expect(without_confidence.errors.of_kind?(:store_confidence, :must_not_be_none_with_store)).to be(true)
  end

  def insert_detection_with_defaults(source_document, text_extraction)
    ActiveRecord::Base.connection.execute(<<~SQL.squish)
      INSERT INTO source_document_detections (
        source_document_id,
        text_extraction_id,
        status,
        created_at,
        updated_at
      )
      VALUES (
        #{ActiveRecord::Base.connection.quote(source_document.id)},
        #{ActiveRecord::Base.connection.quote(text_extraction.id)},
        'needs_classification',
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      )
    SQL
  end

  def enum_values(type_name)
    quoted_type_name = ActiveRecord::Base.connection.quote(type_name)

    ActiveRecord::Base.connection.select_values(<<~SQL.squish)
      SELECT enumlabel
      FROM pg_enum
      JOIN pg_type ON pg_type.oid = pg_enum.enumtypid
      WHERE pg_type.typname = #{quoted_type_name}
      ORDER BY enumsortorder
    SQL
  end
end
