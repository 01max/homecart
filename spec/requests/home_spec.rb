require "rails_helper"

RSpec.describe "Home", type: :request do
  def expect_global_navigation
    expect(response.body).to include(%(data-controller="workspace-nav"))
    expect(response.body).to include(%(id="workspace_nav_collapsed"))
    expect(response.body).to include(%(data-workspace-nav-target="toggle"))
    expect(response.body).to include(%(data-action="workspace-nav#save"))
    expect(response.body).to include(%(href="/receipts"))
    expect(response.body).to include("Receipts")
    expect(response.body).to include(%(href="/source_documents/new"))
    expect(response.body).to include("Upload receipt")
  end

  def create_dashboard_receipt
    store = create(
      :store,
      retail_brand: create(:retail_brand, name: "Whole Foods Market", slug: "whole-foods-market"),
      location_name: "Palo Alto",
      channel: "physical"
    )
    source_document = create(:source_document, store: store, ingested_at: Time.zone.local(2026, 6, 5, 10, 15))
    receipt = create(
      :receipt,
      store: store,
      source_document: source_document,
      parser_status: "needs_review",
      purchased_at: Time.zone.local(2026, 6, 4, 18, 30),
      total_cents: 14_267
    )

    [ receipt, source_document ]
  end

  def expect_dashboard_activity(receipt, source_document)
    expect(response.body).to include(I18n.t("home.index.metrics.needs_review.support", count: 1))
    expect(response.body).to include(%(href="/source_documents"))
    expect(response.body).to include(%(href="/receipts"))
    expect(response.body).to include(%(href="/receipts?parser_status=needs_review"))
    expect(response.body).to include("Whole Foods Market")
    expect(response.body).to include("Palo Alto")
    expect(response.body).to include(I18n.t("receipts.parser_statuses.needs_review"))
    expect(response.body).to include("142,67 €")
    expect(response.body).to include(%(href="/receipts/#{receipt.id}/edit"))
    expect(response.body).to include(%(href="/source_documents/#{source_document.id}"))
  end

  def expect_empty_dashboard
    expect(response.body).to include(I18n.t("home.index.title"))
    expect(response.body).to include(I18n.t("home.index.recent_receipts.empty"))
    expect(response.body).to include(I18n.t("home.index.recent_source_documents.empty"))
    expect(response.body).not_to include("hc-page-actions")
    expect(response.body).not_to include('data-controller="hotwire-smoke"')
  end

  describe "GET /" do
    it "renders an empty operational dashboard" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect_empty_dashboard
      expect_global_navigation
    end

    it "summarizes existing receipt ingestion data" do
      receipt, source_document = create_dashboard_receipt

      get root_path

      expect(response).to have_http_status(:ok)
      expect_dashboard_activity(receipt, source_document)
      expect_global_navigation
    end
  end

  describe "POST /hotwire/ping" do
    it "renders a Turbo Stream replacement" do
      post hotwire_ping_path, headers: { "ACCEPT" => Mime[:turbo_stream].to_s }

      expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
      expect(response.body).to include('<turbo-stream action="replace" target="hotwire_smoke_status">')
    end

    it "renders flash messages through the shared layout partial" do
      post hotwire_ping_path
      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Hotwire is ready.")
      expect(response.body).to include("hc-flash--notice")
    end
  end
end
