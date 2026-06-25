require "rails_helper"

RSpec.describe "Receipt-line matching workflow", type: :system do
  let(:store) { create(:store) }

  it "browses and filters unmatched queue groups" do
    create_lait_lines
    create_line(label: "Compote pomme")

    visit matching_queue_path
    expect_unfiltered_queue_groups

    fill_in I18n.t("matching.queue.index.filters.label_filter"), with: "compote"
    click_button I18n.t("matching.queue.index.filters.submit")
    expect_filtered_queue_groups
  end

  it "falls back to default ordering for unsupported queue sort params" do
    create_orderable_queue_groups

    visit matching_queue_path(sort: "unsupported", direction: "sideways")

    rows = all("tbody tr").map(&:text)
    expect(rows.first).to include("Banane")
    expect(rows.second).to include("Abricot")
    expect(rows.third).to include("Zeste citron")
  end

  it "does not render matching action forms on the queue index" do
    create_lait_lines

    visit matching_queue_path

    expect_no_queue_action_controls
  end

  it "opens a focused group with matching actions from the browse-only queue" do
    records = create_focusable_group_records

    visit matching_queue_path(label_filter: "lait")
    click_link I18n.t("matching.queue.index.actions.open_group")

    expect_focused_group_page(records)
  end

  it "keeps focused line actions scoped to one active receipt line" do
    records = create_focusable_group_records

    visit matching_group_path(records.fetch(:line), label_filter: "lait")
    click_button I18n.t("matching.groups.show.ignore.line_action")

    expect_one_focused_line_ignored(records)
  end

  it "returns stale focused groups to the queue" do
    line = create_line(label: "Compote pomme")
    create(:receipt_line_match, :ignored, receipt_line: line)

    visit matching_group_path(line, label_filter: "compote")

    expect_stale_focused_group_redirect
  end

  it "navigates focused groups while preserving queue context" do
    records = create_sequential_queue_group_records

    visit sequential_group_path(records.fetch(:current_line))
    expect(page).to have_current_path(sequential_group_path(records.fetch(:current_line)))
    navigate_to_next_group(records)
    navigate_to_previous_group(records)
    return_to_sequential_queue
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

  def expect_unfiltered_queue_groups
    expect(page).to have_content(I18n.t("matching.queue.index.table.line_count", count: 2))
    expect(page).to have_content("Lait demi écrémé")
    expect(page).to have_content("Compote pomme")
  end

  def expect_filtered_queue_groups
    expect(page).to have_content("Compote pomme")
    expect(page).to have_no_content("Lait demi écrémé")
  end

  def expect_no_queue_action_controls
    expect(page).to have_no_button(I18n.t("matching.groups.show.suggestions.confirm"))
    expect(page).to have_no_button(I18n.t("matching.groups.show.suggestions.reject"))
    expect(page).to have_no_button(I18n.t("matching.groups.show.ignore.line_action"))
    expect(page).to have_no_link(I18n.t("matching.groups.show.bulk.preview_action"))
    expect(page).to have_no_field(I18n.t("matching.groups.show.search.query"))
    expect(page).to have_no_content(I18n.t("matching.groups.show.inline_catalogue.heading"))
  end

  def expect_focused_group_page(records)
    expect(page).to have_content(I18n.t("matching.groups.show.eyebrow"))
    expect(page).to have_content(I18n.t("matching.groups.show.summary.count", count: 2))
    expect(page).to have_content(records.fetch(:line).label)
    expect(page).to have_content(records.fetch(:sibling_line).label)
    expect(page).to have_no_content(records.fetch(:other_line).label)
    expect_focused_action_controls
  end

  def expect_focused_action_controls
    expect(page).to have_button(I18n.t("matching.groups.show.suggestions.confirm"))
    expect(page).to have_button(I18n.t("matching.groups.show.suggestions.reject"))
    expect(page).to have_link(I18n.t("matching.groups.show.bulk.preview_action"))
    expect(page).to have_field(I18n.t("matching.groups.show.search.query"))
    expect(page).to have_button(I18n.t("matching.groups.show.ignore.line_action"))
    expect(page).to have_button(I18n.t("matching.groups.show.ignore.group_action", count: 2))
    expect(page).to have_content(I18n.t("matching.groups.show.inline_catalogue.heading"))
  end

  def expect_one_focused_line_ignored(records)
    expect(page).to have_content(I18n.t("matching.groups.show.summary.count", count: 1))
    expect(ReceiptLineMatch.ignored.count).to eq(1)
    expect(ReceiptLineMatch.ignored.exists?(receipt_line: records.fetch(:other_line))).to be(false)
  end

  def expect_stale_focused_group_redirect
    expect(page).to have_current_path(matching_queue_path(label_filter: "compote", sort: "line_count", direction: "desc"))
    expect(page).to have_content(I18n.t("matching.groups.show.errors.stale_group"))
    expect(page).to have_content(I18n.t("matching.queue.index.queue.empty"))
  end

  def expect_focused_location(line)
    expect(page).to have_current_path(sequential_group_path(line))
    expect(page).to have_content(line.label)
  end

  def expect_end_of_queue_navigation
    expect(page).to have_no_link(I18n.t("matching.groups.show.actions.next_group"))
    expect(page).to have_link(I18n.t("matching.groups.show.actions.previous_group"))
    expect(page).to have_link(I18n.t("matching.groups.show.actions.back_to_queue"), href: sequential_queue_path)
  end

  def navigate_to_next_group(records)
    click_link I18n.t("matching.groups.show.actions.next_group")
    expect_focused_location(records.fetch(:next_line))
    expect_end_of_queue_navigation
  end

  def navigate_to_previous_group(records)
    click_link I18n.t("matching.groups.show.actions.previous_group")
    expect_focused_location(records.fetch(:current_line))
  end

  def return_to_sequential_queue
    click_link I18n.t("matching.groups.show.actions.back_to_queue")
    expect(page).to have_current_path(sequential_queue_path)
  end

  def create_line(label:, receipt: create(:receipt, :reviewed, store: store, purchased_at: Time.zone.local(2026, 6, 13, 12)))
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

  def create_orderable_queue_groups
    create_line(label: "Zeste citron")
    create_line(label: "Abricot")
    create_line(label: "Banane")
    create_line(label: "Banane")
  end

  def create_focusable_group_records
    create(:category, name: "Dairy")
    create(:retail_brand, name: "E.Leclerc")
    variant = create_variant(product_brand_name: "Maison Dupont", product_name: "Lait demi ecreme", variant_name: "1 L")
    prior_line = create_line(label: "Lait demi ecreme")
    line = create_line(label: "Lait demi écrémé")
    sibling_line = create_line(label: "LAIT DEMI ECREME")
    other_line = create_line(label: "Compote pomme")
    ReceiptLineMatching::ConfirmMatchService.call(receipt_line: prior_line, product_variant: variant)

    { line: line, sibling_line: sibling_line, other_line: other_line }
  end

  def create_sequential_queue_group_records
    {
      current_line: create_line(label: "Fruit Banane"),
      next_line: create_line(label: "Fruit Zeste"),
      previous_line: create_line(label: "Fruit Abricot"),
      filtered_out_line: create_line(label: "Compote pomme")
    }
  end

  def sequential_group_path(line)
    matching_group_path(line, sequential_queue_params)
  end

  def sequential_queue_path
    matching_queue_path(sequential_queue_params)
  end

  def sequential_queue_params
    { label_filter: "fruit", sort: "label", direction: "asc" }
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
