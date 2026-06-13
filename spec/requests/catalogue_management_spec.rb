require "rails_helper"

RSpec.describe "Catalogue management", type: :request do
  describe "catalogue dashboard" do
    it "links to the catalogue management screens" do
      get catalogue_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(href="/catalogue/product_brands"))
      expect(response.body).to include(%(href="/catalogue/products"))
      expect(response.body).to include(%(href="/catalogue/product_variants"))
      expect(response.body).to include(%(href="/catalogue/product_alternative_groups"))
    end
  end

  describe "index pages" do
    it "renders each catalogue index without missing translations" do
      catalogue_index_paths.each { |path| expect_index_to_render(path) }
    end
  end

  describe "product brands" do
    it "creates a national product brand without a retail-brand owner" do
      expect { post_national_product_brand }.to change(ProductBrand, :count).by(1)

      product_brand = ProductBrand.find_by!(name: "Maison Dupont")
      expect(product_brand.retail_brand).to be_nil
      expect_redirected_body_to_include("Maison Dupont", I18n.t("product_catalog.labels.empty_value"))
    end

    it "creates a private-label product brand linked to a retail brand" do
      retail_brand = create(:retail_brand, name: "E.Leclerc")

      expect { post_private_label_product_brand(retail_brand) }.to change(ProductBrand, :count).by(1)

      product_brand = ProductBrand.find_by!(name: "Bio Village")
      expect(product_brand.retail_brand).to eq(retail_brand)
      expect_redirected_body_to_include("Bio Village")
    end
  end

  describe "reference records" do
    it "creates a manufacturer" do
      expect do
        post catalogue_manufacturers_path, params: { manufacturer: { name: "Andros SNC" } }
      end.to change(Manufacturer, :count).by(1)

      follow_redirect!
      expect(response.body).to include("Andros SNC")
    end

    it "creates a comparison unit" do
      expect do
        post catalogue_comparison_units_path, params: { comparison_unit: { name: "Slice", symbol: "slice" } }
      end.to change(ComparisonUnit, :count).by(1)

      follow_redirect!
      expect(response.body).to include("Slice")
      expect(response.body).to include("slice")
    end
  end

  describe "products and variants" do
    it "renders the category picker on the product form" do
      create_nested_category

      get new_catalogue_product_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Pantry &gt; Snacks")
      expect(response.body).to include(I18n.t("product_catalog.category_picker.manage_categories"))
    end

    it "shows matching existing variants before product creation" do
      variant = create_compote_variant
      create_ham_variant

      get new_catalogue_product_path, params: { catalogue_search_query: "epicerie compote bio village" }

      expect_search_results_to_include(variant)
      expect(response.body).not_to include("4 tranches")
    end

    it "creates a product without a manufacturer" do
      category = create(:category, name: "Compotes")
      product_brand = create(:product_brand, name: "Bio Village")

      expect { post_product_without_manufacturer(category, product_brand) }.to change(Product, :count).by(1)

      product = Product.find_by!(name: "Compotes pomme")
      expect(product.manufacturer).to be_nil
      expect_redirected_body_to_include("Compotes pomme", "Not set")
    end

    it "rejects creating a product without a category" do
      product_brand = create(:product_brand, name: "Bio Village")

      expect { post_product_without_category(product_brand) }.not_to change(Product, :count)
    end

    it "creates a product variant without a barcode" do
      product = create(:product, name: "Compotes pomme")
      comparison_unit = create(:comparison_unit, name: "Gram", symbol: "g")

      expect { post_variant_without_barcode(product, comparison_unit) }.to change(ProductVariant, :count).by(1)

      variant = ProductVariant.find_by!(name: "12 x 90g")
      expect(variant.barcode).to be_nil
      expect_redirected_body_to_include("12 x 90g", "12 x 90.0 g")
    end

    it "shows matching existing variants before variant creation" do
      variant = create_compote_variant

      get new_catalogue_product_variant_path, params: { catalogue_search_query: "compote bio" }

      expect_search_results_to_include(variant)
    end

    it "creates a product and variant through the inline variant form" do
      category = create(:category, name: "Compotes")

      expect { post_inline_product_variant(category) }
        .to change(Product, :count).by(1)
        .and change(ProductVariant, :count).by(1)

      expect(Product.find_by!(name: "Compotes pomme").category).to eq(category)
      expect_redirected_body_to_include("12 x 90g")
    end

    it "rejects inline product and variant creation without a category" do
      expect { post_inline_product_variant_without_category }
        .not_to change(ProductVariant, :count)

      expect(Product.find_by(name: "Compotes pomme")).to be_nil
    end
  end

  describe "alternative groups" do
    it "creates a group and adds a variant member" do
      category = create(:category, name: "Jambon")
      variant = create(:product_variant, product: create(:product, category: category), name: "4 slices")

      expect { post_alternative_group(category) }.to change(ProductAlternativeGroup, :count).by(1)

      group = ProductAlternativeGroup.find_by!(name: "Jambon blanc tranches")
      expect { post_alternative_group_membership(group, variant) }
        .to change(ProductAlternativeGroupMembership, :count).by(1)
      expect_redirected_body_to_include("4 slices", "Equivalent")
    end
  end

  def catalogue_index_paths
    [
      catalogue_product_brands_path,
      catalogue_manufacturers_path,
      catalogue_comparison_units_path,
      catalogue_products_path,
      catalogue_product_variants_path,
      catalogue_product_alternative_groups_path
    ]
  end

  def expect_index_to_render(path)
    get path

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("translation missing")
  end

  def post_national_product_brand
    post catalogue_product_brands_path,
         params: { product_brand: { name: "Maison Dupont", retail_brand_id: "" } }
  end

  def post_private_label_product_brand(retail_brand)
    post catalogue_product_brands_path,
         params: { product_brand: { name: "Bio Village", retail_brand_id: retail_brand.id } }
  end

  def post_product_without_manufacturer(category, product_brand)
    post catalogue_products_path,
         params: {
           product: {
             name: "Compotes pomme",
             product_brand_id: product_brand.id,
             category_id: category.id,
             manufacturer_id: ""
           }
         }
  end

  def post_product_without_category(product_brand)
    post catalogue_products_path,
         params: {
           product: {
             name: "Compotes pomme",
             product_brand_id: product_brand.id,
             category_id: "",
             manufacturer_id: ""
           }
         }
  end

  def post_variant_without_barcode(product, comparison_unit)
    post catalogue_product_variants_path,
         params: {
           product_variant: {
             product_id: product.id,
             name: "12 x 90g",
             package_count: "12",
             quantity_value: "90",
             comparison_unit_id: comparison_unit.id,
             barcode: ""
           }
         }
  end

  def post_inline_product_variant(category)
    post inline_product_catalogue_product_variants_path,
         params: { inline_product_variant: inline_product_variant_params(category_id: category.id) }
  end

  def post_inline_product_variant_without_category
    post inline_product_catalogue_product_variants_path,
         params: { inline_product_variant: inline_product_variant_params(category_id: "") }
  end

  def inline_product_variant_params(category_id:)
    {
      product_brand_name: "Bio Village",
      product_name: "Compotes pomme",
      category_id: category_id,
      manufacturer_name: "",
      variant_name: "12 x 90g",
      package_count: "12",
      quantity_value: "90",
      comparison_unit_id: "",
      barcode: ""
    }
  end

  def create_catalogue_variant(product_brand_name:, product_name:, variant_name:)
    product_brand = create(:product_brand, name: product_brand_name)
    product = create(:product, product_brand: product_brand, name: product_name)

    create(:product_variant, product: product, name: variant_name)
  end

  def create_compote_variant
    create_catalogue_variant(
      product_brand_name: "Bio Village",
      product_name: "Compotes pomme",
      variant_name: "12 x 90g"
    )
  end

  def create_ham_variant
    create_catalogue_variant(
      product_brand_name: "Maison Dupont",
      product_name: "Jambon blanc",
      variant_name: "4 tranches"
    )
  end

  def expect_search_results_to_include(variant)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(variant.name)
    expect(response.body).to include(catalogue_product_variant_path(variant))
    expect(response.body).to include(I18n.t("product_catalog.search.choose_existing"))
  end

  def post_alternative_group(category)
    post catalogue_product_alternative_groups_path,
         params: { product_alternative_group: { name: "Jambon blanc tranches", category_id: category.id } }
  end

  def post_alternative_group_membership(group, variant)
    post catalogue_product_alternative_group_memberships_path(group),
         params: {
           product_alternative_group_membership: {
             product_variant_id: variant.id,
             equivalence: "equivalent"
           }
         }
  end

  def expect_redirected_body_to_include(*snippets)
    follow_redirect!

    expect(response.body).to include(*snippets)
    expect(response.body).not_to include("translation missing")
  end

  def create_nested_category
    root = create(:category, name: "Pantry")
    create(:category, name: "Snacks", parent: root)
  end
end
