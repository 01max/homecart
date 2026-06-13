module Catalogue
  # Manages shopper-facing products under brands and categories.
  class ProductsController < BaseController
    before_action :load_product, only: %i[show edit update]
    before_action :load_form_options, only: %i[new edit create update]

    def index
      @products = Product.includes(:category, :manufacturer, :product_brand, :product_variants).order(:normalized_name)
    end

    def show
      @product_variants = @product.product_variants.includes(:comparison_unit).order(:normalized_name)
    end

    def new
      @product = Product.new
    end

    def create
      @product = Product.new(product_params.except(:name).transform_values { |value| blank_to_nil(value) })
      assign_catalogue_identity(@product, product_params[:name])

      if @product.save
        redirect_to catalogue_product_path(@product),
                    notice: t("product_catalog.products.create.success", name: @product.name)
      else
        redirect_with_record_errors(new_catalogue_product_path, @product)
      end
    end

    def edit
    end

    def update
      @product.assign_attributes(product_params.except(:name).transform_values { |value| blank_to_nil(value) })
      assign_catalogue_identity(@product, product_params[:name])

      if @product.save
        redirect_to catalogue_product_path(@product),
                    notice: t("product_catalog.products.update.success", name: @product.name)
      else
        redirect_with_record_errors(edit_catalogue_product_path(@product), @product)
      end
    end

    private

    def load_product
      @product = Product.includes(:category, :manufacturer, :product_brand).find(params[:id])
    end

    def load_form_options
      @categories = Category.includes(:parent).order(:normalized_name)
      @manufacturers = Manufacturer.order(:normalized_name)
      @product_brands = ProductBrand.includes(:retail_brand).order(:normalized_name)
    end

    def product_params
      params.require(:product).permit(:name, :product_brand_id, :manufacturer_id, :category_id)
    end
  end
end
