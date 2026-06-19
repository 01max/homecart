require "rails_helper"

RSpec.describe "Catalogue", type: :request do
  describe "GET /catalogue" do
    it "renders the catalogue entry screen" do
      get catalogue_root_path

      expect(response).to have_http_status(:ok)
      expect_catalogue_entry_links
    end
  end

  def expect_catalogue_entry_links
    expect(response.body).to include(
      I18n.t("product_catalog.dashboard.index.title"),
      %(href="/catalogue/categories"),
      %(href="/catalogue/product_brands"),
      %(href="/catalogue/products"),
      %(href="/catalogue/product_variants"),
      %(href="/matching")
    )
  end
end
