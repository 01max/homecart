module ProductCatalog
  # Creates one category, optionally under an existing parent category.
  class CreateCategoryService < ApplicationService
    def initialize(name:, parent: nil)
      @name = name
      @parent = parent
    end

    def call
      Category.create!(
        name: name,
        normalized_name: normalized_name,
        slug: slug,
        parent: parent
      )
    end

    private

    attr_reader :name, :parent

    def normalized_name
      NormalizeTextService.call(name)
    end

    def slug
      name.to_s.parameterize
    end
  end
end
