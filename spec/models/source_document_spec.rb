require "rails_helper"

RSpec.describe SourceDocument do
  let(:source_document) { create(:source_document, content_hash: "a" * 64) }

  it "belongs to a store" do
    expect(source_document.store.source_documents).to contain_exactly(source_document)
  end

  it "owns source detection attempts" do
    detection = create(:source_document_detection, source_document: source_document)

    expect(source_document.source_document_detections).to contain_exactly(detection)
  end

  it "declares accepted MIME types" do
    expect(described_class.mime_types).to include("pdf" => "application/pdf", "png" => "image/png", "jpeg" => "image/jpeg")
  end

  it "declares parser formats" do
    expect(described_class.parser_formats.keys).to include("auchan_paper_v1", "leclerc_paper_v1", "u_paper_v2")
  end

  it "declares source detection statuses" do
    expect(described_class.source_detection_statuses.keys).to contain_exactly("pending", "classified", "needs_classification")
  end

  it "validates content hash format" do
    document = described_class.new(store: source_document.store, content_hash: "not-sha")

    expect(document).not_to be_valid
    expect(document.errors[:content_hash]).to include("is invalid")
  end

  it "validates required upload metadata" do
    document = described_class.new(store: source_document.store, content_hash: "b" * 64)

    expect(document).not_to be_valid
    expect(document.errors[:mime_type]).to include("can't be blank")
    expect(document.errors[:ingested_at]).to include("can't be blank")
  end

  it "requires a source detection status" do
    document = build(:source_document, source_detection_status: nil)

    expect(document).not_to be_valid
    expect(document.errors[:source_detection_status]).to include("can't be blank")
  end

  it "requires store and parser format when classified" do
    document = build(:source_document, :pending_classification, source_detection_status: "classified")

    expect(document).not_to be_valid
    expect(document.errors[:store]).to include("can't be blank")
    expect(document.errors[:parser_format]).to include("can't be blank")
  end

  it "allows pending classification without store or parser format" do
    expect(build(:source_document, :pending_classification)).to be_valid
  end

  it "requires content hash uniqueness" do
    duplicate = source_document.dup

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:content_hash]).to include("has already been taken")
  end

  it "rejects evidence changes through Active Record" do
    expect { source_document.update!(content_hash: "b" * 64) }
      .to raise_error(ActiveRecord::RecordInvalid, /Content hash is immutable/)

    expect(source_document.reload.content_hash).to eq("a" * 64)
  end

  it "rejects evidence changes through direct SQL" do
    quoted_id = ActiveRecord::Base.connection.quote(source_document.id)
    sql = "UPDATE source_documents SET content_hash = '#{'c' * 64}' WHERE id = #{quoted_id}"

    expect { execute_in_savepoint(sql) }
      .to raise_error(ActiveRecord::StatementInvalid, /source_documents evidence columns are immutable/)
  end

  it "allows Rails bookkeeping changes" do
    expect(source_document.update!(updated_at: 1.minute.from_now)).to be(true)
  end
end
