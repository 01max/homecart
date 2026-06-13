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
      store = create(:store, location_name: "Massy")
      create_line(store: store, label: "Lait demi écrémé", total_cents: 672, unit_price_cents: 672)
      create_line(store: store, label: "LAIT DEMI ECREME", total_cents: 695, unit_price_cents: 695)

      get matching_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Lait demi écrémé")
      expect(response.body).to include("lait demi ecreme")
      expect(response.body).to include(I18n.t("matching.queue.index.table.line_count", count: 2))
      expect(response.body).to include("Massy")
      expect(response.body).to include("6,72 €")
      expect(response.body).to include("6,95 €")
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
  end
end
