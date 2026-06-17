module Catalogue
  # Handles catalogue category management screens.
  class CategoriesController < BaseController
    before_action :load_category, only: %i[update destroy]
    before_action :load_categories, only: %i[index new]

    def index
    end

    def new
      render :index
    end

    def create
      category = ProductCatalog::CreateCategoryService.call(
        name: category_params[:name],
        parent: selected_parent
      )

      redirect_to catalogue_categories_path, notice: t("product_catalog.categories.create.success", name: category.name)
    rescue ActiveRecord::RecordInvalid => e
      redirect_to catalogue_categories_path, alert: e.record.errors.full_messages.to_sentence
    end

    def update
      category = ProductCatalog::UpdateCategoryService.call(
        category: @category,
        name: category_params[:name],
        parent: selected_parent_or_existing_parent
      )

      redirect_to catalogue_categories_path, notice: t("product_catalog.categories.update.success", name: category.name)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid => e
      redirect_to catalogue_categories_path, alert: category_error_message(e)
    end

    def destroy
      ProductCatalog::DeleteCategoryService.call(category: @category)

      redirect_to catalogue_categories_path, notice: t("product_catalog.categories.destroy.success", name: @category.name)
    rescue ProductCatalog::DeleteCategoryService::CategoryInUseError => e
      redirect_to catalogue_categories_path, alert: e.message
    end

    private

    def load_category
      @category = Category.find(params[:id])
    end

    def load_categories
      @q = catalogue_ransack_search(
        Category.includes(:parent, :children, :products, :product_alternative_groups),
        default_sort: "normalized_name asc"
      )
      @categories = @q.result
      @root_categories = @categories.select { |category| category.parent_id.nil? }
      @children_by_parent = @categories.group_by(&:parent_id)
    end

    def category_params
      params.require(:category).permit(:name, :parent_id)
    end

    def selected_parent
      return if category_params[:parent_id].blank?

      Category.find(category_params[:parent_id])
    end

    def selected_parent_or_existing_parent
      return @category.parent unless category_params.key?(:parent_id)

      selected_parent
    end

    def category_error_message(error)
      return error.record.errors.full_messages.to_sentence if error.respond_to?(:record)

      t("product_catalog.categories.errors.invalid_tree")
    end
  end
end
