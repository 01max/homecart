require "rails_helper"

RSpec.describe TextExtraction do
  let(:retail_brand) { RetailBrand.create!(name: "Retailer B", slug: "retailer-b", aliases: []) }
  let(:store) do
    Store.create!(
      retail_brand: retail_brand,
      location_name: "Location 01",
      channel: "physical",
      identifiers: {}
    )
  end
  let(:source_document) do
    SourceDocument.create!(
      store: store,
      content_hash: "a" * 64,
      mime_type: "application/pdf",
      parser_format: "leclerc.paper.v1",
      ingested_at: Time.current
    )
  end
  let(:text_extraction) do
    described_class.create!(
      source_document: source_document,
      engine: "pdftotext-layout",
      text: "raw receipt text",
      ran_at: Time.current,
      success: true
    )
  end

  def execute_in_savepoint(sql)
    ActiveRecord::Base.transaction(requires_new: true) do
      ActiveRecord::Base.connection.execute(sql)
    end
  end

  it "rejects evidence changes through Active Record" do
    expect { text_extraction.update!(text: "corrected text") }
      .to raise_error(ActiveRecord::RecordInvalid, /Text is immutable/)

    expect(text_extraction.reload.text).to eq("raw receipt text")
  end

  it "rejects evidence changes through direct SQL" do
    extraction = text_extraction
    quoted_id = ActiveRecord::Base.connection.quote(extraction.id)
    sql = "UPDATE text_extractions SET engine = 'manual-edit' WHERE id = #{quoted_id}"

    expect { execute_in_savepoint(sql) }
      .to raise_error(ActiveRecord::StatementInvalid, /text_extractions evidence columns are immutable/)

    expect(extraction.reload.engine).to eq("pdftotext-layout")
  end

  it "allows Rails bookkeeping changes" do
    expect(text_extraction.update!(updated_at: 1.minute.from_now)).to be(true)
  end
end
