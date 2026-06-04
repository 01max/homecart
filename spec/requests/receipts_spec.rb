require "rails_helper"

RSpec.describe "Receipts", type: :request do
  let(:retail_brand) { create(:retail_brand, slug: "leclerc").tap { |brand| brand.update!(name: "E.Leclerc") } }
  let(:store) { create(:store, retail_brand: retail_brand, location_name: "Villeneuve sur Lot", channel: "physical") }

  def create_listed_receipt(parser_status:, purchased_at:, total_cents: 1_234)
    create(:receipt,
      store: store,
      parser_status: parser_status,
      purchased_at: purchased_at,
      total_cents: total_cents
    )
  end

  def receipt_rows
    response.body.scan(%r{<tr(?:\s[^>]*)?>.*?</tr>}m)
  end

  def create_filterable_receipts
    create_listed_receipt(parser_status: "parsed", purchased_at: 2.days.ago, total_cents: 1111)
    create_listed_receipt(parser_status: "needs_review", purchased_at: 1.day.ago, total_cents: 2_222)
    create_listed_receipt(parser_status: "reviewed", purchased_at: Time.current, total_cents: 3_333)
  end

  it "lists receipts newest first" do
    older_receipt = create_listed_receipt(parser_status: "parsed", purchased_at: 2.days.ago, total_cents: 1_111)
    newer_receipt = create_listed_receipt(parser_status: "needs_review", purchased_at: 1.day.ago, total_cents: 2_222)

    get receipts_path

    rows = receipt_rows
    expect(response).to have_http_status(:ok)
    expect(rows.index { |row| row.include?(formatted_total(newer_receipt)) })
      .to be < rows.index { |row| row.include?(formatted_total(older_receipt)) }
    expect(response.body).to include("E.Leclerc — Villeneuve sur Lot (physical)")
  end

  it "filters receipts by parser status" do
    create_filterable_receipts

    get receipts_path, params: { parser_status: "needs_review" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("receipts.parser_statuses.needs_review"))
    expect(response.body).to include("22,22 €")
    expect(response.body).not_to include("11,11 €")
    expect(response.body).not_to include("33,33 €")
  end

  it "ignores unknown parser status filters" do
    create_listed_receipt(parser_status: "parsed", purchased_at: Time.current, total_cents: 1111)

    get receipts_path, params: { parser_status: "unknown" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("11,11 €")
  end

  it "renders the empty state" do
    get receipts_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("receipts.index.empty"))
  end

  def formatted_total(receipt)
    "#{receipt.total_cents / 100},#{receipt.total_cents % 100} €"
  end
end
