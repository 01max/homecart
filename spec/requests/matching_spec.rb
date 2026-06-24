require "rails_helper"

RSpec.describe "Matching", type: :request do
  describe "GET /matching" do
    it "renders the matching queue entry screen" do
      get matching_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("matching.queue.index.title"))
      expect(response.body).to include(%(href="/catalogue"))
    end

    it "renders unmatched item lines grouped by normalized label" do
      create_lait_lines

      get matching_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include_matching_queue_group
    end

    it "excludes fees and discounts from the default queue" do
      create_line(label: "Reusable bag fee", kind: "fee")
      create_line(label: "Immediate discount", kind: "discount")

      get matching_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("matching.queue.index.queue.empty"))
      expect(response.body).not_to include("Reusable bag fee")
      expect(response.body).not_to include("Immediate discount")
    end

    it "filters the queue by receipt label while keeping non-item and terminal lines excluded" do
      create_filterable_queue_groups

      get matching_root_path, params: { label_filter: "lait" }

      expect_filtered_matching_queue
    end

    it "falls back to the default queue order for unsupported ordering params" do
      create_orderable_queue_groups

      get matching_root_path, params: { sort: "unsupported", direction: "sideways" }

      expect(response).to have_http_status(:ok)
      expect_queue_labels_in_order([ "Banane", "Abricot", "Zeste citron" ])
    end

    it "omits full matching action forms from the queue index" do
      create_action_ready_queue_group

      get matching_root_path

      expect_browse_only_matching_queue
    end
  end

  describe "GET /matching/groups/:id" do
    it "links queue groups to the focused matching page" do
      line = create_line(label: "Compote pomme")

      get matching_root_path, params: { label_filter: "compote", sort: "label", direction: "asc" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(focused_group_href(line, label_filter: "compote", sort: "label", direction: "asc"))
    end

    it "renders the current queue group from a representative receipt line" do
      records = create_focused_group_records

      get matching_group_path(records.fetch(:representative_line))

      expect_focused_group(records)
    end

    it "redirects stale focused groups back to the queue with localized feedback" do
      line = create_line(label: "Lait demi ecreme")
      create(:receipt_line_match, :ignored, receipt_line: line)

      get matching_group_path(line, label_filter: "lait", sort: "label", direction: "asc")

      expect(response).to redirect_to(matching_queue_path(label_filter: "lait", sort: "label", direction: "asc"))
      expect(flash[:alert]).to eq(I18n.t("matching.groups.show.errors.stale_group"))
    end
  end

  describe "GET /matching/receipts/:id" do
    it "renders only one receipt's unmatched item lines with prior-label suggestions" do
      records = create_receipt_specific_matching_records

      expect do
        get matching_receipt_path(records.fetch(:receipt))
      end.not_to change(ReceiptLineMatch.suggested, :count)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include_receipt_matching_page(records.fetch(:line), records.fetch(:variant))
      expect_receipt_matching_page_to_exclude_other_lines
      expect(ReceiptLineMatch.confirmed.exists?(receipt_line: records.fetch(:line))).to be(false)
    end

    it "redirects receipts without purchase dates back to review" do
      receipt = create(:receipt, :reviewed, purchased_at: nil)

      get matching_receipt_path(receipt)

      expect(response).to redirect_to(receipt_path(receipt))
      expect(flash[:alert]).to eq(I18n.t("matching.receipts.show.errors.purchase_date_required"))
    end
  end

  describe "POST /matching/receipt_lines/:id/confirm" do
    it "confirms the selected variant for one receipt line" do
      variant = create(:product_variant)
      line = create_line(label: "Compote pomme")

      expect do
        post confirm_matching_receipt_line_path(line), params: { product_variant_id: variant.id }
      end.to change(ReceiptLineMatch.confirmed, :count).by(1)

      expect(response).to redirect_to(matching_queue_path)
      expect(line.receipt_line_matches.confirmed.last.product_variant).to eq(variant)
    end

    it "rejects receipt lines without purchase dates" do
      variant = create(:product_variant)
      receipt = create(:receipt, :reviewed, purchased_at: nil)
      line = create_line(receipt: receipt, label: "Compote pomme")

      expect do
        post confirm_matching_receipt_line_path(line), params: { product_variant_id: variant.id }
      end.not_to change(ReceiptLineMatch.confirmed, :count)

      expect(response).to redirect_to(matching_queue_path)
      expect(flash[:alert]).to eq(I18n.t("matching.receipt_lines.errors.purchase_date_required"))
    end
  end

  describe "POST /matching/receipt_lines/:id/confirm with return_to" do
    it "returns to the receipt-specific matching page" do
      variant = create(:product_variant)
      line = create_line(label: "Compote pomme")

      post confirm_matching_receipt_line_path(line),
           params: { product_variant_id: variant.id, return_to: matching_receipt_path(line.receipt) }

      expect(response).to redirect_to(matching_receipt_path(line.receipt))
    end
  end

  describe "POST /matching/receipt_lines/:id/ignore" do
    it "ignores one line without creating catalogue data or price observations" do
      line = create_line(label: "Do not match")
      counts = catalogue_and_price_counts

      expect do
        post ignore_matching_receipt_line_path(line)
      end.to change(ReceiptLineMatch.ignored, :count).by(1)

      expect(response).to redirect_to(matching_queue_path)
      expect_catalogue_and_price_counts(counts)
      expect(ReceiptLineMatching::QueueService.call.flat_map(&:receipt_lines)).not_to include(line)
    end
  end

  describe "POST /matching/receipt_lines/:id/reject" do
    it "rejects the selected variant for one receipt line" do
      variant = create(:product_variant)
      line = create_line(label: "Compote pomme")

      expect do
        post reject_matching_receipt_line_path(line), params: { product_variant_id: variant.id }
      end.to change(ReceiptLineMatch.rejected, :count).by(1)

      expect(response).to redirect_to(matching_queue_path)
      expect(line.receipt_line_matches.rejected.last.product_variant).to eq(variant)
    end
  end

  describe "POST /matching/receipt_lines/:id/create_variant" do
    it "creates an inline private-label variant and confirms the receipt line" do
      records = create_inline_catalogue_records
      line = create_line(label: "Compote pomme")

      expect do
        post_create_inline_variant(line, **records)
      end.to change(ProductVariant, :count).by(1)
        .and change(ReceiptLineMatch.confirmed, :count).by(1)

      expect(response).to redirect_to(matching_queue_path)
      expect_inline_private_label_confirmation(line, records.fetch(:retail_brand))
    end

    it "rejects inline creation without a category" do
      line = create_line(label: "Compote pomme")

      expect do
        post_create_inline_variant(line, category: nil)
      end.not_to change(ProductVariant, :count)

      expect(response).to redirect_to(matching_queue_path)
      expect(flash[:alert]).to eq(I18n.t("matching.receipt_lines.create_variant.errors.category_required"))
    end
  end

  describe "POST /matching/bulk_confirmations" do
    it "confirms the previewed line count" do
      variant = create(:product_variant)
      create_lait_lines
      preview = ReceiptLineMatching::BulkConfirmService.preview(normalized_label: "Lait demi ecreme")

      expect do
        post_bulk_confirmation("Lait demi ecreme", variant, receipt_line_ids: preview.receipt_line_ids)
      end.to change(ReceiptLineMatch.confirmed, :count).by(2)

      expect(response).to redirect_to(matching_queue_path)
      expect(flash[:notice]).to include("Confirmed 2 lines")
    end

    it "rejects stale bulk confirmations" do
      variant = create(:product_variant)
      create_line(label: "Lait demi ecreme")

      expect do
        post_bulk_confirmation("Lait demi ecreme", variant, receipt_line_ids: [ SecureRandom.uuid ])
      end.not_to change(ReceiptLineMatch.confirmed, :count)

      expect(response).to redirect_to(matching_queue_path)
      expect(flash[:alert]).to eq(I18n.t("matching.bulk_confirmations.create.errors.stale_preview"))
    end
  end

  describe "POST /matching/ignored_groups" do
    it "ignores all currently eligible lines in the group without creating variants" do
      create_lait_lines
      preview = ReceiptLineMatching::BulkConfirmService.preview(normalized_label: "Lait demi ecreme")
      counts = catalogue_and_price_counts

      expect do
        post_ignored_group("Lait demi ecreme", receipt_line_ids: preview.receipt_line_ids)
      end.to change(ReceiptLineMatch.ignored, :count).by(2)

      expect_group_ignore_success(counts)
    end

    it "rejects stale grouped ignores" do
      create_line(label: "Lait demi ecreme")

      expect do
        post_ignored_group("Lait demi ecreme", receipt_line_ids: [ SecureRandom.uuid ])
      end.not_to change(ReceiptLineMatch.ignored, :count)

      expect(response).to redirect_to(matching_queue_path)
      expect(flash[:alert]).to eq(I18n.t("matching.ignored_groups.create.errors.stale_preview"))
    end
  end

  def create_line(
    store: create(:store),
    receipt: create(:receipt, :reviewed, store: store, purchased_at: Time.zone.local(2026, 6, 13, 12)),
    label:,
    kind: "item",
    total_cents: 123,
    unit_price_cents: total_cents
  )
    create(
      :receipt_line,
      receipt: receipt,
      label: label,
      kind: kind,
      quantity: 1,
      total_cents: total_cents,
      unit_price_cents: unit_price_cents
    )
  end

  def create_variant(product_brand_name:, product_name:, variant_name:)
    product_brand = create(:product_brand, name: product_brand_name)
    product = create(:product, product_brand: product_brand, name: product_name)

    create(:product_variant, product: product, name: variant_name)
  end

  def create_prior_confirmation(label:)
    variant = create_variant(product_brand_name: "Maison Dupont", product_name: "Jambon blanc", variant_name: "4 tranches")
    prior_line = create_line(label: label)

    ReceiptLineMatching::ConfirmMatchService.call(receipt_line: prior_line, product_variant: variant)
    variant
  end

  def create_receipt_specific_exclusions(receipt)
    create_line(receipt: receipt, label: "Service fee", kind: "fee")
    ignored_line = create_line(receipt: receipt, label: "Ignored item")
    create(:receipt_line_match, :ignored, receipt_line: ignored_line)
  end

  def create_receipt_specific_matching_records
    receipt = create(:receipt, parser_status: "reviewed")
    variant = create_prior_confirmation(label: "Jambon blanc 4 tranches")
    line = create_line(receipt: receipt, label: "JAMBON BLANC 4 TRANCHES")
    create_receipt_specific_exclusions(receipt)
    create_line(label: "Other receipt line")

    { receipt: receipt, variant: variant, line: line }
  end

  def create_inline_catalogue_records
    {
      category: create(:category, name: "Compotes"),
      retail_brand: create(:retail_brand, name: "E.Leclerc")
    }
  end

  def post_create_inline_variant(line, category:, retail_brand: nil)
    post create_variant_matching_receipt_line_path(line),
         params: { inline_product_variant: inline_variant_params(category: category, retail_brand: retail_brand) }
  end

  def post_bulk_confirmation(normalized_label, variant, receipt_line_ids:)
    post matching_bulk_confirmations_path,
         params: {
           bulk_confirmation: {
             normalized_label: normalized_label,
             product_variant_id: variant.id,
             receipt_line_ids: receipt_line_ids
           }
         }
  end

  def post_ignored_group(normalized_label, receipt_line_ids:)
    post matching_ignored_groups_path,
         params: {
           ignored_group: {
             normalized_label: normalized_label,
             receipt_line_ids: receipt_line_ids
           }
         }
  end

  def catalogue_and_price_counts
    {
      product_variants: ProductVariant.count,
      price_observations: PriceObservation.count
    }
  end

  def expect_catalogue_and_price_counts(counts)
    expect_catalogue_counts(counts)
    expect(PriceObservation.count).to eq(counts.fetch(:price_observations))
  end

  def expect_catalogue_counts(counts)
    expect(ProductVariant.count).to eq(counts.fetch(:product_variants))
  end

  def expect_group_ignore_success(counts)
    expect(response).to redirect_to(matching_queue_path)
    expect_catalogue_counts(counts)
    expect(flash[:notice]).to include("Ignored 2 lines")
    expect(ReceiptLineMatching::QueueService.call.flat_map(&:receipt_lines)).to be_empty
  end

  def inline_variant_params(category:, retail_brand:)
    {
      product_brand_name: "Bio Village",
      retail_brand_id: retail_brand&.id,
      product_name: "Compotes pomme",
      category_id: category&.id,
      manufacturer_name: "",
      variant_name: "12 x 90g",
      package_count: "12",
      quantity_value: "90",
      comparison_unit_id: "",
      barcode: ""
    }
  end

  def expect_inline_private_label_confirmation(line, retail_brand)
    variant = ProductVariant.last

    expect(variant.product.product_brand).to have_attributes(name: "Bio Village", retail_brand: retail_brand)
    expect(variant.product).to have_attributes(name: "Compotes pomme", manufacturer: nil)
    expect(variant).to have_attributes(name: "12 x 90g", package_count: 12)
    expect(line.receipt_line_matches.confirmed.last.product_variant).to eq(variant)
  end

  def create_lait_lines
    store = create(:store, location_name: "Massy")
    create_line(store: store, label: "Lait demi écrémé", total_cents: 672, unit_price_cents: 672)
    create_line(store: store, label: "LAIT DEMI ECREME", total_cents: 695, unit_price_cents: 695)
  end

  def create_filterable_queue_groups
    create_lait_lines
    create_line(label: "Compote pomme")
    create_line(label: "Lait reusable bag", kind: "fee")
    ignored_line = create_line(label: "Lait ignored")
    create(:receipt_line_match, :ignored, receipt_line: ignored_line)
    confirmed_line = create_line(label: "Lait confirmed")
    create(:receipt_line_match, receipt_line: confirmed_line)
  end

  def create_action_ready_queue_group
    create_prior_confirmation(label: "Lait demi ecreme")
    create_lait_lines
    create(:category, name: "Dairy")
    create(:retail_brand, name: "E.Leclerc")
  end

  def create_orderable_queue_groups
    create_line(label: "Zeste citron")
    create_line(label: "Abricot")
    create_line(label: "Banane")
    create_line(label: "Banane")
  end

  def create_focused_group_records
    representative_line = create_line(label: "Lait demi écrémé")
    sibling_line = create_line(label: "LAIT DEMI ECREME")
    other_line = create_line(label: "Compote pomme")

    { representative_line: representative_line, sibling_line: sibling_line, other_line: other_line }
  end

  def include_matching_queue_group
    include("Lait demi écrémé")
      .and include("lait demi ecreme")
      .and include(I18n.t("matching.queue.index.table.line_count", count: 2))
      .and include("Massy")
      .and include("6,72 €")
      .and include("6,95 €")
  end

  def expect_filtered_matching_queue
    expect(response).to have_http_status(:ok)
    expect(response.body).to include_matching_queue_group
    expect(response.body).not_to include("Compote pomme")
    expect(response.body).not_to include("Lait reusable bag")
    expect(response.body).not_to include("Lait ignored")
    expect(response.body).not_to include("Lait confirmed")
  end

  def expect_browse_only_matching_queue
    expect(response).to have_http_status(:ok)
    expect(response.body).to include_matching_queue_group
    expect(response.body).not_to match(%r{action="/matching/receipt_lines/[^"]+"})
    expect(response.body).not_to include(%(action="#{matching_bulk_confirmations_path}"))
    expect(response.body).not_to include(%(action="#{matching_ignored_groups_path}"))
    expect(response.body).not_to include(I18n.t("matching.queue.index.bulk.preview_action"))
    expect(response.body).not_to include(I18n.t("matching.queue.index.search.query"))
    expect(response.body).not_to include(I18n.t("matching.queue.index.ignore.line_action"))
    expect(response.body).not_to include(I18n.t("matching.queue.index.inline_catalogue.heading"))
  end

  def expect_focused_group(records)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("matching.groups.show.eyebrow"))
    expect(response.body).to include(records.fetch(:representative_line).label)
    expect(response.body).to include(records.fetch(:sibling_line).label)
    expect(response.body).not_to include(records.fetch(:other_line).label)
  end

  def focused_group_href(line, params)
    ERB::Util.html_escape(matching_group_path(line, params))
  end

  def include_receipt_matching_page(line, variant)
    include(I18n.t("matching.receipts.show.title"))
      .and include(line.label)
      .and include(catalogue_product_variant_label_for_test(variant))
      .and include(I18n.t("matching.queue.index.suggestions.reasons.prior_confirmed_label"))
  end

  def expect_receipt_matching_page_to_exclude_other_lines
    expect(response.body).not_to include("Service fee")
    expect(response.body).not_to include("Ignored item")
    expect(response.body).not_to include("Other receipt line")
  end

  def queue_rows
    response.body.scan(%r{<tr(?:\s[^>]*)?>.*?</tr>}m)
  end

  def expect_queue_labels_in_order(labels)
    positions = labels.map do |label|
      queue_rows.index { |row| row.include?(label) }
    end

    expect(positions).to all(be_a(Integer))
    expect(positions).to eq(positions.sort)
  end

  def catalogue_product_variant_label_for_test(variant)
    I18n.t(
      "product_catalog.labels.variant",
      product: I18n.t(
        "product_catalog.labels.product",
        brand: variant.product.product_brand.name,
        product: variant.product.name,
        category: variant.product.category.name
      ),
      variant: variant.name
    )
  end
end
