module Catalogue
  # Manages concrete purchasable variants.
  class ProductVariantsController < BaseController
    before_action :load_product_variant, only: %i[show edit update]
    before_action :load_form_options, only: %i[new edit create update]
    before_action :load_catalogue_variant_search_results, only: %i[new]

    def index
      @q = catalogue_ransack_search(
        ProductVariant.includes(:comparison_unit, product: %i[category product_brand]),
        default_sort: "normalized_name asc"
      )
      @pagy, @product_variants = pagy(@q.result)
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

    def inline_product
      result = ProductCatalog::CreateVariantService.call(
        product_brand_name: inline_product_variant_params[:product_brand_name],
        product_name: inline_product_variant_params[:product_name],
        variant_name: inline_product_variant_params[:variant_name],
        category: inline_category,
        manufacturer_name: inline_product_variant_params[:manufacturer_name],
        comparison_unit: inline_comparison_unit,
        package_count: blank_to_nil(inline_product_variant_params[:package_count]),
        quantity_value: blank_to_nil(inline_product_variant_params[:quantity_value]),
        barcode: blank_to_nil(inline_product_variant_params[:barcode])
      )

      redirect_to catalogue_product_variant_path(result.variant),
                  notice: t("product_catalog.product_variants.inline_product.success", name: result.variant.name)
    rescue ActiveRecord::RecordInvalid => e
      redirect_to new_catalogue_product_variant_path, alert: e.record.errors.full_messages.to_sentence
    rescue ActiveRecord::RecordNotFound
      redirect_to new_catalogue_product_variant_path,
                  alert: t("product_catalog.product_variants.inline_product.errors.category_required")
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
      @categories = Category.includes(:parent).order(:normalized_name)
      @comparison_units = ComparisonUnit.order(:normalized_name)
    end

    def product_variant_params
      params.require(:product_variant)
        .permit(:name, :product_id, :comparison_unit_id, :package_count, :quantity_value, :barcode)
    end

    def inline_product_variant_params
      params.require(:inline_product_variant).permit(
        :product_brand_name,
        :product_name,
        :variant_name,
        :category_id,
        :manufacturer_name,
        :comparison_unit_id,
        :package_count,
        :quantity_value,
        :barcode
      )
    end

    def inline_category
      raise ActiveRecord::RecordNotFound if inline_product_variant_params[:category_id].blank?

      Category.find(inline_product_variant_params[:category_id])
    end

    def inline_comparison_unit
      return if inline_product_variant_params[:comparison_unit_id].blank?

      ComparisonUnit.find(inline_product_variant_params[:comparison_unit_id])
    end
  end
end
