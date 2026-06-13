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

    it "renders deterministic suggestions with confirm and reject actions" do
      create_prior_jambon_confirmation
      create_line(label: "JAMBON BLANC 4 TRANCHES")

      get matching_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include_matching_suggestion_actions
    end

    it "renders existing variant search results for the selected group" do
      create_variant(product_brand_name: "Bio Village", product_name: "Compotes pomme", variant_name: "12 x 90g")
      create_line(label: "Compote pomme")

      get matching_root_path, params: variant_search_params("Compote pomme", "Bio Village compote")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include_variant_search_result
    end

    it "renders inline catalogue creation controls" do
      create(:category, name: "Compotes")
      create(:retail_brand, name: "E.Leclerc")
      create_line(label: "Compote pomme")

      get matching_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include_inline_catalogue_form
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

  def create_line(store: create(:store), label:, kind: "item", total_cents: 123, unit_price_cents: total_cents)
    create(
      :receipt_line,
      receipt: create(:receipt, store: store, purchased_at: Time.zone.local(2026, 6, 13, 12)),
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

  def create_prior_jambon_confirmation
    variant = create_variant(product_brand_name: "Maison Dupont", product_name: "Jambon blanc", variant_name: "4 tranches")
    prior_line = create_line(label: "Jambon blanc 4 tranches")

    ReceiptLineMatching::ConfirmMatchService.call(receipt_line: prior_line, product_variant: variant)
  end

  def variant_search_params(label, query)
    {
      variant_search_label: ProductCatalog::NormalizeTextService.call(label),
      variant_search_query: query
    }
  end

  def include_matching_queue_group
    include("Lait demi écrémé")
      .and include("lait demi ecreme")
      .and include(I18n.t("matching.queue.index.table.line_count", count: 2))
      .and include("Massy")
      .and include("6,72 €")
      .and include("6,95 €")
  end

  def include_matching_suggestion_actions
    include("Maison Dupont")
      .and include(I18n.t("matching.queue.index.suggestions.reasons.prior_confirmed_label"))
      .and include(I18n.t("matching.queue.index.suggestions.confirm"))
      .and include(I18n.t("matching.queue.index.suggestions.reject"))
  end

  def include_variant_search_result
    include("Bio Village")
      .and include("12 x 90g")
      .and include(I18n.t("matching.queue.index.search.confirm"))
  end

  def include_inline_catalogue_form
    include(I18n.t("matching.queue.index.inline_catalogue.heading"))
      .and include(I18n.t("matching.queue.index.inline_catalogue.product_brand_name"))
      .and include(I18n.t("matching.queue.index.inline_catalogue.no_retail_brand"))
      .and include("E.Leclerc")
      .and include("Compotes")
  end
end
