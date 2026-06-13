require "rails_helper"

RSpec.describe "Receipt-line matching workflow", type: :system do
  let(:store) { create(:store) }

  it "shows grouped matching suggestions and confirms one line with a price observation" do
    variant = create_prior_label_variant
    create_lait_lines

    visit matching_queue_path
    expect(page).to have_content(I18n.t("matching.queue.index.table.line_count", count: 2))
    click_button I18n.t("matching.queue.index.suggestions.confirm"), match: :first

    expect(page).to have_content("Confirmed")
    expect(ReceiptLineMatch.confirmed.where(product_variant: variant).count).to eq(2)
    expect(PriceObservation.where(product_variant: variant).count).to eq(2)
  end

  it "creates an inline variant from the queue and confirms the line" do
    records = create_inline_catalogue_records
    create_line(label: "Compote pomme")

    visit matching_queue_path
    fill_inline_catalogue_form(**records)
    click_button I18n.t("matching.queue.index.inline_catalogue.create")

    expect(page).to have_content("Created 12 x 90g and confirmed Compote pomme.")
    expect_inline_catalogue_confirmation(records.fetch(:retail_brand))
  end

  it "bulk-confirms a grouped label after previewing the affected count" do
    create_prior_label_variant
    create_lait_lines

    visit matching_queue_path
    click_link I18n.t("matching.queue.index.bulk.preview_action"), match: :first
    click_button I18n.t("matching.queue.index.bulk.confirm", count: 2)

    expect(page).to have_content("Confirmed 2 lines")
    expect(ReceiptLineMatch.confirmed.count).to eq(3)
  end

  it "rejects and ignores queue entries without creating price observations" do
    create_rejectable_compote_line

    visit matching_queue_path
    click_button I18n.t("matching.queue.index.suggestions.reject"), match: :first
    expect(page).to have_content("Rejected suggestion for Compote pomme.")

    click_button I18n.t("matching.queue.index.ignore.line_action"), match: :first
    expect_rejected_line_to_be_ignored
  end

  it "ignores a grouped label from the queue" do
    create_lait_lines

    visit matching_queue_path
    click_button I18n.t("matching.queue.index.ignore.group_action", count: 2)

    expect(page).to have_content("Ignored 2 lines")
    expect(ReceiptLineMatch.ignored.count).to eq(2)
    expect(page).to have_content(I18n.t("matching.queue.index.queue.empty"))
  end

  it "matches only one reviewed receipt without auto-confirming suggestions" do
    records = create_receipt_specific_records

    visit receipt_path(records.fetch(:receipt))
    click_link I18n.t("receipts.show.actions.match_receipt", count: 1)

    expect(page).to have_content(I18n.t("matching.receipts.show.title"))
    expect(page).to have_content("JAMBON BLANC 4 TRANCHES")
    expect(page).to have_content("Maison Dupont")
    expect(page).not_to have_content("Other receipt line")
    expect(ReceiptLineMatch.confirmed.exists?(receipt_line: records.fetch(:line))).to be(false)
  end

  def create_line(label:, receipt: create(:receipt, store: store, purchased_at: Time.zone.local(2026, 6, 13, 12)))
    create(:receipt_line, receipt: receipt, label: label, quantity: 1, total_cents: 123, unit_price_cents: 123)
  end

  def create_lait_lines
    create_line(label: "Lait demi écrémé")
    create_line(label: "LAIT DEMI ECREME")
  end

  def create_variant(product_brand_name:, product_name:, variant_name:)
    product_brand = create(:product_brand, name: product_brand_name)
    product = create(:product, product_brand: product_brand, name: product_name)

    create(:product_variant, product: product, name: variant_name)
  end

  def create_prior_label_variant
    create_variant(
      product_brand_name: "Maison Dupont",
      product_name: "Lait demi ecreme",
      variant_name: "6 x 1L"
    ).tap do |variant|
      prior_line = create_line(label: "Lait demi ecreme")
      ReceiptLineMatching::ConfirmMatchService.call(receipt_line: prior_line, product_variant: variant)
    end
  end

  def create_compote_variant
    create_variant(
      product_brand_name: "Bio Village",
      product_name: "Compotes pomme",
      variant_name: "12 x 90g"
    )
  end

  def create_inline_catalogue_records
    {
      category: create(:category, name: "Compotes"),
      retail_brand: create(:retail_brand, name: "E.Leclerc")
    }
  end

  def create_rejectable_compote_line
    create_compote_variant
    create_line(label: "Compote pomme")
  end

  def fill_inline_catalogue_form(category:, retail_brand:)
    fill_in I18n.t("matching.queue.index.inline_catalogue.product_brand_name"), with: "Bio Village"
    select retail_brand.name, from: I18n.t("matching.queue.index.inline_catalogue.retail_brand")
    fill_in I18n.t("matching.queue.index.inline_catalogue.product_name"), with: "Compotes pomme"
    select category.name, from: I18n.t("matching.queue.index.inline_catalogue.category")
    fill_in I18n.t("matching.queue.index.inline_catalogue.variant_name"), with: "12 x 90g"
  end

  def expect_inline_catalogue_confirmation(retail_brand)
    expect(ProductBrand.last).to have_attributes(name: "Bio Village", retail_brand: retail_brand)
    expect(ReceiptLineMatch.confirmed.last.product_variant.name).to eq("12 x 90g")
  end

  def expect_rejected_line_to_be_ignored
    expect(page).to have_content("Ignored Compote pomme.")
    expect(ReceiptLineMatch.rejected.count).to eq(1)
    expect(ReceiptLineMatch.ignored.count).to eq(1)
    expect(PriceObservation.count).to eq(0)
  end

  def create_receipt_specific_records
    receipt = create(:receipt, store: store, parser_status: "reviewed")
    variant = create_variant(product_brand_name: "Maison Dupont", product_name: "Jambon blanc", variant_name: "4 tranches")
    prior_line = create_line(label: "Jambon blanc 4 tranches")
    line = create_line(receipt: receipt, label: "JAMBON BLANC 4 TRANCHES")
    create_line(label: "Other receipt line")
    ReceiptLineMatching::ConfirmMatchService.call(receipt_line: prior_line, product_variant: variant)

    { receipt: receipt, line: line }
  end
end
