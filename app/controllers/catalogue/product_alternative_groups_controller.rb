module Catalogue
  # Manages explicit variant-level alternative groups.
  class ProductAlternativeGroupsController < BaseController
    before_action :load_product_alternative_group, only: %i[show edit update]
    before_action :load_form_options, only: %i[new edit create update]

    def index
      @q = catalogue_ransack_search(
        ProductAlternativeGroup.includes(:category, :product_variants),
        default_sort: "name asc"
      )
      @product_alternative_groups = @q.result
    end

    def show
      @memberships = @product_alternative_group.product_alternative_group_memberships
        .includes(product_variant: [ :comparison_unit, { product: %i[category product_brand] } ])
        .order(:created_at)
      @product_variants = ProductVariant.includes(:comparison_unit, product: %i[category product_brand]).order(:normalized_name)
    end

    def new
      @product_alternative_group = ProductAlternativeGroup.new
    end

    def create
      @product_alternative_group = ProductAlternativeGroup.new(product_alternative_group_params)

      if @product_alternative_group.save
        redirect_to catalogue_product_alternative_group_path(@product_alternative_group),
                    notice: t("product_catalog.product_alternative_groups.create.success", name: @product_alternative_group.name)
      else
        redirect_with_record_errors(new_catalogue_product_alternative_group_path, @product_alternative_group)
      end
    end

    def edit
    end

    def update
      @product_alternative_group.assign_attributes(product_alternative_group_params)

      if @product_alternative_group.save
        redirect_to catalogue_product_alternative_group_path(@product_alternative_group),
                    notice: t("product_catalog.product_alternative_groups.update.success", name: @product_alternative_group.name)
      else
        redirect_with_record_errors(edit_catalogue_product_alternative_group_path(@product_alternative_group),
                                    @product_alternative_group)
      end
    end

    private

    def load_product_alternative_group
      @product_alternative_group = ProductAlternativeGroup.includes(:category).find(params[:id])
    end

    def load_form_options
      @categories = Category.includes(:parent).order(:normalized_name)
    end

    def product_alternative_group_params
      params.require(:product_alternative_group).permit(:name, :category_id)
    end
  end
end
