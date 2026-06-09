module ProductCatalog
  # Renames and/or moves an existing category.
  class UpdateCategoryService < ApplicationService
    def initialize(category:, name:, parent:)
      @category = category
      @name = name
      @parent = parent
    end

    def call
      category.update!(attributes)
      category
    end

    private

    attr_reader :category, :name, :parent

    def attributes
      {
        name: updated_name,
        normalized_name: NormalizeTextService.call(updated_name),
        slug: updated_name.to_s.parameterize,
        parent: parent
      }
    end

    def updated_name
      name.nil? ? category.name : name
    end
  end
end
