require "rails_helper"

RSpec.describe "Matching", type: :request do
  describe "GET /matching" do
    it "renders the matching queue entry screen" do
      get matching_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("matching.queue.index.title"))
      expect(response.body).to include(%(href="/catalogue"))
    end
  end
end
