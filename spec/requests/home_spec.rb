require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    it "renders the Hotwire smoke page" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("turbo-cable-stream-source")
      expect(response.body).to include('data-controller="hotwire-smoke"')
    end
  end

  describe "POST /hotwire/ping" do
    it "renders a Turbo Stream replacement" do
      post hotwire_ping_path, headers: { "ACCEPT" => Mime[:turbo_stream].to_s }

      expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
      expect(response.body).to include('<turbo-stream action="replace" target="hotwire_smoke_status">')
    end
  end
end
