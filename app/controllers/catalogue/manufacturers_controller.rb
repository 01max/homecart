module Catalogue
  # Manages optional manufacturer enrichment records.
  class ManufacturersController < BaseController
    before_action :load_manufacturer, only: %i[show edit update]

    def index
      @q = catalogue_ransack_search(Manufacturer.includes(:products), default_sort: "normalized_name asc")
      @pagy, @manufacturers = pagy(@q.result)
    end

    def show
      @products = @manufacturer.products.includes(:category, :product_brand, :product_variants).order(:normalized_name)
    end

    def new
      @manufacturer = Manufacturer.new
    end

    def create
      @manufacturer = Manufacturer.new
      assign_catalogue_identity(@manufacturer, manufacturer_params[:name])

      if @manufacturer.save
        redirect_to catalogue_manufacturer_path(@manufacturer),
                    notice: t("product_catalog.manufacturers.create.success", name: @manufacturer.name)
      else
        redirect_with_record_errors(new_catalogue_manufacturer_path, @manufacturer)
      end
    end

    def edit
    end

    def update
      assign_catalogue_identity(@manufacturer, manufacturer_params[:name])

      if @manufacturer.save
        redirect_to catalogue_manufacturer_path(@manufacturer),
                    notice: t("product_catalog.manufacturers.update.success", name: @manufacturer.name)
      else
        redirect_with_record_errors(edit_catalogue_manufacturer_path(@manufacturer), @manufacturer)
      end
    end

    private

    def load_manufacturer
      @manufacturer = Manufacturer.find(params[:id])
    end

    def manufacturer_params
      params.require(:manufacturer).permit(:name)
    end
  end
end
