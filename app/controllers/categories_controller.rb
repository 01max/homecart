# Handles catalogue category mutations while services own persistence rules.
class CategoriesController < ApplicationController
  before_action :load_category, only: %i[update destroy]

  def create
    category = ProductCatalog::CreateCategoryService.call(
      name: category_params[:name],
      parent: selected_parent
    )

    redirect_to category_redirect_location, notice: t(".success", name: category.name)
  rescue ActiveRecord::RecordInvalid => e
    redirect_to category_redirect_location, alert: e.record.errors.full_messages.to_sentence
  end

  def update
    category = ProductCatalog::UpdateCategoryService.call(
      category: @category,
      name: category_params[:name],
      parent: selected_parent_or_existing_parent
    )

    redirect_to category_redirect_location, notice: t(".success", name: category.name)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid => e
    redirect_to category_redirect_location, alert: category_error_message(e)
  end

  def destroy
    ProductCatalog::DeleteCategoryService.call(category: @category)

    redirect_to category_redirect_location, notice: t(".success", name: @category.name)
  rescue ProductCatalog::DeleteCategoryService::CategoryInUseError => e
    redirect_to category_redirect_location, alert: e.message
  end

  private

  def load_category
    @category = Category.find(params[:id])
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

  def category_redirect_location
    url_from(request.referer) || root_path
  end
end
