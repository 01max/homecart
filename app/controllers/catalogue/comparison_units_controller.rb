module Catalogue
  # Manages units used for variant-level price comparison.
  class ComparisonUnitsController < BaseController
    before_action :load_comparison_unit, only: %i[show edit update]

    def index
      @comparison_units = ComparisonUnit.includes(:product_variants).order(:normalized_name)
    end

    def show
      @product_variants = @comparison_unit.product_variants.includes(product: %i[product_brand category]).order(:normalized_name)
    end

    def new
      @comparison_unit = ComparisonUnit.new
    end

    def create
      @comparison_unit = ComparisonUnit.new(symbol: comparison_unit_params[:symbol])
      assign_catalogue_identity(@comparison_unit, comparison_unit_params[:name])

      if @comparison_unit.save
        redirect_to catalogue_comparison_unit_path(@comparison_unit),
                    notice: t("product_catalog.comparison_units.create.success", name: @comparison_unit.name)
      else
        redirect_with_record_errors(new_catalogue_comparison_unit_path, @comparison_unit)
      end
    end

    def edit
    end

    def update
      @comparison_unit.symbol = comparison_unit_params[:symbol]
      assign_catalogue_identity(@comparison_unit, comparison_unit_params[:name])

      if @comparison_unit.save
        redirect_to catalogue_comparison_unit_path(@comparison_unit),
                    notice: t("product_catalog.comparison_units.update.success", name: @comparison_unit.name)
      else
        redirect_with_record_errors(edit_catalogue_comparison_unit_path(@comparison_unit), @comparison_unit)
      end
    end

    private

    def load_comparison_unit
      @comparison_unit = ComparisonUnit.find(params[:id])
    end

    def comparison_unit_params
      params.require(:comparison_unit).permit(:name, :symbol)
    end
  end
end
