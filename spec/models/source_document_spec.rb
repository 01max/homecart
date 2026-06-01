require "rails_helper"

RSpec.describe SourceDocument do
  let(:retail_brand) { RetailBrand.create!(name: "E.Leclerc", slug: "leclerc", aliases: []) }
  let(:store) do
    Store.create!(
      retail_brand: retail_brand,
      location_name: "Villeneuve sur Lot",
      channel: "physical",
      identifiers: {}
    )
  end
  let(:source_document) do
    described_class.create!(
      store: store,
      content_hash: "a" * 64,
      mime_type: "application/pdf",
      parser_format: "leclerc.paper.v1",
      ingested_at: Time.current
    )
  end

  def execute_in_savepoint(sql)
    ActiveRecord::Base.transaction(requires_new: true) do
      ActiveRecord::Base.connection.execute(sql)
    end
  end

  it "rejects evidence changes through Active Record" do
    expect { source_document.update!(content_hash: "b" * 64) }
      .to raise_error(ActiveRecord::RecordInvalid, /Content hash is immutable/)

    expect(source_document.reload.content_hash).to eq("a" * 64)
  end

  it "rejects evidence changes through direct SQL" do
    document = source_document
    sql = "UPDATE source_documents SET content_hash = '#{'c' * 64}' WHERE id = #{document.id}"

    expect { execute_in_savepoint(sql) }
      .to raise_error(ActiveRecord::StatementInvalid, /source_documents evidence columns are immutable/)

    expect(document.reload.content_hash).to eq("a" * 64)
  end

  it "allows Rails bookkeeping changes" do
    expect(source_document.update!(updated_at: 1.minute.from_now)).to be(true)
  end
end
