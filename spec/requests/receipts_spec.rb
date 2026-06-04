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

  def create_review_receipt
    source_document = create(:source_document, store: store)
    text_extraction = create(:text_extraction, source_document: source_document, text: "RAW LINE\nTOTAL 12,34")
    receipt = create(
      :receipt,
      store: store,
      source_document: source_document,
      text_extraction: text_extraction,
      purchased_at: Time.zone.local(2026, 6, 1, 9, 15),
      register_number: "101",
      ticket_number: "12345",
      cashier_code: "C12",
      total_cents: 1_234,
      declared_article_count: 2,
      parser_status: "needs_review"
    )
    create(:receipt_line, receipt: receipt, position: 1, label: "Original label", raw_text: "ORIGINAL RAW", total_cents: 1_234)
    receipt
  end

  def review_receipt_params
    {
      receipt: {
        purchased_at: "2026-06-02T10:30",
        register_number: "202",
        ticket_number: "54321",
        cashier_code: "D34",
        total_cents: "2345",
        declared_article_count: "4"
      }
    }
  end

  def review_receipt_line_params(receipt:, replacement_store:)
    edited_line, removed_line = receipt.receipt_lines.order(:position)
    {
      receipt: {
        store_id: replacement_store.id,
        receipt_lines_attributes: {
          "0" => {
            id: edited_line.id,
            position: "1",
            raw_text: "UPDATED RAW",
            label: "Updated label",
            quantity: "2",
            unit_of_measure: "piece",
            unit_price_cents: "250",
            total_cents: "500",
            kind: "item",
            tr_eligible: "1",
            section_label: "UPDATED SECTION"
          },
          "1" => { id: removed_line.id, _destroy: "1" },
          "2" => {
            position: "3",
            raw_text: "NEW RAW",
            label: "New label",
            quantity: "1",
            unit_of_measure: "kg",
            unit_price_cents: "345",
            total_cents: "345",
            kind: "fee",
            tr_eligible: "0",
            section_label: "NEW SECTION"
          }
        }
      }
    }
  end

  def review_receipt_line_params_with_blank_row(receipt)
    line = receipt.receipt_lines.sole
    {
      receipt: {
        receipt_lines_attributes: {
          "0" => {
            id: line.id,
            position: line.position.to_s,
            raw_text: line.raw_text,
            label: line.label,
            quantity: line.quantity.to_s,
            unit_of_measure: line.unit_of_measure,
            total_cents: line.total_cents.to_s,
            kind: line.kind,
            tr_eligible: "0"
          },
          "1" => {
            position: "2",
            raw_text: "",
            label: "",
            quantity: "1.0",
            unit_of_measure: "piece",
            unit_price_cents: "",
            total_cents: "",
            kind: "item",
            tr_eligible: "0",
            section_label: ""
          }
        }
      }
    }
  end

  def expect_review_page
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("RAW LINE\nTOTAL 12,34")
    expect(response.body).to include(I18n.t("receipts.edit.form.heading"))
    expect(response.body).to include(I18n.t("receipts.edit.form.store"))
    expect(response.body).to include(I18n.t("receipts.edit.form.total_cents"))
    expect(response.body).to include(I18n.t("receipts.edit.lines.heading"))
    expect(response.body).to include(%(name="receipt[total_cents]"))
    expect(response.body).to include(%q(name="receipt[receipt_lines_attributes]))
    expect(response.body).not_to include(%(name="text_extraction[text]"))
  end

  def expect_receipt_to_be_updated(receipt)
    expect(response).to redirect_to(edit_receipt_path(receipt))
    expect(flash[:notice]).to eq(I18n.t("receipts.update.success"))
    expect(receipt.reload).to have_attributes(
      purchased_at: Time.zone.local(2026, 6, 2, 10, 30),
      register_number: "202",
      ticket_number: "54321",
      cashier_code: "D34",
      total_cents: 2_345,
      declared_article_count: 4
    )
  end

  def expect_receipt_lines_to_be_updated(receipt, replacement_store)
    receipt.reload
    edited_line = receipt.receipt_lines.find_by!(position: 1)
    new_line = receipt.receipt_lines.find_by!(position: 3)

    expect(receipt.store).to eq(replacement_store)
    expect(receipt.receipt_lines.count).to eq(2)
    expect(edited_line).to have_attributes(label: "Updated label", raw_text: "UPDATED RAW", total_cents: 500)
    expect(edited_line).to be_tr_eligible
    expect(new_line).to have_attributes(label: "New label", unit_of_measure: "kg", kind: "fee", total_cents: 345)
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

  it "renders the side-by-side review page with extracted text and receipt form" do
    receipt = create_review_receipt

    get edit_receipt_path(receipt)

    expect_review_page
  end

  it "updates editable receipt header fields" do
    receipt = create_review_receipt

    patch receipt_path(receipt), params: review_receipt_params

    expect_receipt_to_be_updated(receipt)
  end

  it "updates store and receipt lines through nested attributes" do
    receipt = create_review_receipt
    create(:receipt_line, receipt: receipt, position: 2, label: "Removed label")
    replacement_store = create(:store, retail_brand: retail_brand, location_name: "Other location", channel: "drive")

    patch receipt_path(receipt), params: review_receipt_line_params(receipt: receipt, replacement_store: replacement_store)

    expect_receipt_lines_to_be_updated(receipt, replacement_store)
  end

  it "ignores the blank add-row when default controls submit values" do
    receipt = create_review_receipt

    patch receipt_path(receipt), params: review_receipt_line_params_with_blank_row(receipt)

    expect(response).to redirect_to(edit_receipt_path(receipt))
    expect(receipt.reload.receipt_lines.count).to eq(1)
  end

  def formatted_total(receipt)
    "#{receipt.total_cents / 100},#{receipt.total_cents % 100} €"
  end
end
