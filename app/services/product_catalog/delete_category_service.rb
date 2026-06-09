module ProductCatalog
  # Deletes unused categories and rejects categories that still anchor catalogue data.
  class DeleteCategoryService < ApplicationService
    CategoryInUseError = Class.new(StandardError)

    def initialize(category:)
      @category = category
    end

    def call
      raise CategoryInUseError, in_use_message if category_in_use?

      category.destroy!
    end

    private

    attr_reader :category

    def category_in_use?
      category.children.exists? ||
        category.products.exists? ||
        category.product_alternative_groups.exists?
    end

    def in_use_message
      I18n.t("product_catalog.categories.errors.in_use")
    end
  end
end
