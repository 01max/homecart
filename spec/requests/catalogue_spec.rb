require "rails_helper"

RSpec.describe "Catalogue", type: :request do
  describe "GET /catalogue" do
    it "renders the catalogue entry screen" do
      get catalogue_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("product_catalog.dashboard.index.title"))
      expect(response.body).to include(%(href="/matching"))
    end
  end
end
