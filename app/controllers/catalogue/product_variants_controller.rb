module Catalogue
  # Manages concrete purchasable variants.
  class ProductVariantsController < BaseController
    before_action :load_product_variant, only: %i[show edit update]
    before_action :load_form_options, only: %i[new edit create update]

    def index
      @product_variants = ProductVariant.includes(:comparison_unit, product: %i[category product_brand]).order(:normalized_name)
    end

    def show
    end

    def new
      @product_variant = ProductVariant.new(product_id: params[:product_id])
    end

    def create
      @product_variant = ProductVariant.new(product_variant_params.except(:name).transform_values { |value| blank_to_nil(value) })
      assign_catalogue_identity(@product_variant, product_variant_params[:name])

      if @product_variant.save
        redirect_to catalogue_product_variant_path(@product_variant),
                    notice: t("product_catalog.product_variants.create.success", name: @product_variant.name)
      else
        redirect_with_record_errors(new_catalogue_product_variant_path, @product_variant)
      end
    end

    def edit
    end

    def update
      @product_variant.assign_attributes(product_variant_params.except(:name).transform_values { |value| blank_to_nil(value) })
      assign_catalogue_identity(@product_variant, product_variant_params[:name])

      if @product_variant.save
        redirect_to catalogue_product_variant_path(@product_variant),
                    notice: t("product_catalog.product_variants.update.success", name: @product_variant.name)
      else
        redirect_with_record_errors(edit_catalogue_product_variant_path(@product_variant), @product_variant)
      end
    end

    private

    def load_product_variant
      @product_variant = ProductVariant.includes(:comparison_unit, product: %i[category product_brand manufacturer]).find(params[:id])
    end

    def load_form_options
      @products = Product.includes(:category, :product_brand).order(:normalized_name)
      @comparison_units = ComparisonUnit.order(:normalized_name)
    end

    def product_variant_params
      params.require(:product_variant)
        .permit(:name, :product_id, :comparison_unit_id, :package_count, :quantity_value, :barcode)
    end
  end
end
