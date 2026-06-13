require "rails_helper"

RSpec.describe "Catalogue categories", type: :request do
  describe "GET /catalogue/categories" do
    it "renders the category workbench" do
      get catalogue_categories_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("product_catalog.categories.index.title"))
      expect(response.body).to include(I18n.t("product_catalog.categories.index.empty"))
    end

    it "displays nested category breadcrumbs" do
      create_category_tree

      get catalogue_categories_path

      expect(response.body).to include("Epicerie sucree &gt; Gouter &gt; Compotes")
    end
  end

  describe "category mutations" do
    it "creates a nested category" do
      parent = create(:category, name: "Gouter")

      expect { post catalogue_categories_path, params: category_params(name: "Compotes", parent: parent) }
        .to change(Category, :count).by(1)
      expect(Category.find_by!(name: "Compotes").parent).to eq(parent)
    end

    it "renames and moves a category" do
      target = create(:category, name: "Compotes")
      parent = create(:category, name: "Epicerie sucree")

      patch catalogue_category_path(target), params: category_params(name: "Desserts", parent: parent)

      expect(target.reload).to have_attributes(name: "Desserts", parent: parent)
    end

    it "deletes an unused category" do
      category = create(:category)

      expect { delete catalogue_category_path(category) }.to change(Category, :count).by(-1)
    end

    it "rejects deleting a category in use" do
      category = create(:category)
      create(:product, category: category)

      expect { delete catalogue_category_path(category) }.not_to change(Category, :count)
      follow_redirect!
      expect(response.body).to include(I18n.t("product_catalog.categories.errors.in_use"))
    end
  end

  def category_params(name:, parent: nil)
    { category: { name: name, parent_id: parent&.id } }
  end

  def create_category_tree
    root = create(:category, name: "Epicerie sucree")
    parent = create(:category, name: "Gouter", parent: root)
    create(:category, name: "Compotes", parent: parent)
  end
end
