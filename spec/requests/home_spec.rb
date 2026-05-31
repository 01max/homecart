require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    it "renders the Hotwire smoke page" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("turbo-cable-stream-source")
      expect(response.body).to include('data-controller="hotwire-smoke"')
      expect(response.body).to include(%(href="/receipts"))
      expect(response.body).to include("Receipts")
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
      expect(response.body).to include("border-emerald-200")
    end
  end
end
