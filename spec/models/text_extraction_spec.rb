require "rails_helper"

RSpec.describe TextExtraction do
  let(:source_document) { create_source_document(content_hash: "a" * 64) }
  let(:text_extraction) { create_text_extraction(source_document: source_document) }

  it "belongs to a source document" do
    expect(source_document.text_extractions).to contain_exactly(text_extraction)
  end

  it "can own one parsed receipt" do
    receipt = create_receipt(source_document: source_document, text_extraction: text_extraction)

    expect(text_extraction.receipt).to eq(receipt)
  end

  it "requires text when successful" do
    extraction = described_class.new(source_document: source_document, engine: "pdftotext-layout", ran_at: Time.current, success: true)

    expect(extraction).not_to be_valid
    expect(extraction.errors[:text]).to include("can't be blank")
  end

  it "requires an error message when failed" do
    extraction = described_class.new(source_document: source_document, engine: "pdftotext-layout", ran_at: Time.current, success: false)

    expect(extraction).not_to be_valid
    expect(extraction.errors[:error_message]).to include("can't be blank")
  end

  it "allows failed attempts with an error message" do
    extraction = described_class.new(
      source_document: source_document,
      engine: "pdftotext-layout",
      ran_at: Time.current,
      success: false,
      error_message: "empty text"
    )

    expect(extraction).to be_valid
  end

  it "rejects evidence changes through Active Record" do
    expect { text_extraction.update!(text: "corrected text") }
      .to raise_error(ActiveRecord::RecordInvalid, /Text is immutable/)

    expect(text_extraction.reload.text).to eq("raw receipt text")
  end

  it "rejects evidence changes through direct SQL" do
    quoted_id = ActiveRecord::Base.connection.quote(text_extraction.id)
    sql = "UPDATE text_extractions SET engine = 'manual-edit' WHERE id = #{quoted_id}"

    expect { execute_in_savepoint(sql) }
      .to raise_error(ActiveRecord::StatementInvalid, /text_extractions evidence columns are immutable/)
  end

  it "allows Rails bookkeeping changes" do
    expect(text_extraction.update!(updated_at: 1.minute.from_now)).to be(true)
  end
end
