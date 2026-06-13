module Catalogue
  module CategoriesHelper
    def category_breadcrumb_text(category)
      category_path_to_root(category).map(&:name).join(t("product_catalog.categories.breadcrumb_separator"))
    end

    def category_parent_options(categories, category: nil)
      excluded_ids = category ? [ category.id, *category_descendant_ids(category) ] : []

      categories.reject { |candidate| excluded_ids.include?(candidate.id) }
        .map { |candidate| [ category_breadcrumb_text(candidate), candidate.id ] }
    end

    private

    def category_path_to_root(category)
      path = []

      while category
        path.unshift(category)
        category = category.parent
      end

      path
    end

    def category_descendant_ids(category)
      category.children.flat_map { |child| [ child.id, *category_descendant_ids(child) ] }
    end
  end
end
