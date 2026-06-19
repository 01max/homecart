module Catalogue
  # Manages product-facing brands, including private-label links.
  class ProductBrandsController < BaseController
    before_action :load_product_brand, only: %i[show edit update]
    before_action :load_retail_brands, only: %i[new edit create update]

    def index
      @q = catalogue_ransack_search(
        ProductBrand.includes(:retail_brand, :products),
        default_sort: "normalized_name asc"
      )
      @pagy, @product_brands = pagy(@q.result)
    end

    def show
      @products = @product_brand.products.includes(:category, :manufacturer, :product_variants).order(:normalized_name)
    end

    def new
      @product_brand = ProductBrand.new
    end

    def create
      @product_brand = ProductBrand.new(retail_brand_id: blank_to_nil(product_brand_params[:retail_brand_id]))
      assign_catalogue_identity(@product_brand, product_brand_params[:name])

      if @product_brand.save
        redirect_to catalogue_product_brand_path(@product_brand),
                    notice: t("product_catalog.product_brands.create.success", name: @product_brand.name)
      else
        redirect_with_record_errors(new_catalogue_product_brand_path, @product_brand)
      end
    end

    def edit
    end

    def update
      @product_brand.retail_brand_id = blank_to_nil(product_brand_params[:retail_brand_id])
      assign_catalogue_identity(@product_brand, product_brand_params[:name])

      if @product_brand.save
        redirect_to catalogue_product_brand_path(@product_brand),
                    notice: t("product_catalog.product_brands.update.success", name: @product_brand.name)
      else
        redirect_with_record_errors(edit_catalogue_product_brand_path(@product_brand), @product_brand)
      end
    end

    private

    def load_product_brand
      @product_brand = ProductBrand.includes(:retail_brand).find(params[:id])
    end

    def load_retail_brands
      @retail_brands = RetailBrand.order(:name)
    end

    def product_brand_params
      params.require(:product_brand).permit(:name, :retail_brand_id)
    end
  end
end
