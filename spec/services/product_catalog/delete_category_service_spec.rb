require "rails_helper"

RSpec.describe ProductCatalog::DeleteCategoryService do
  def expect_delete_rejected(category)
    expect do
      described_class.call(category: category)
    end.to raise_error(described_class::CategoryInUseError, I18n.t("product_catalog.categories.errors.in_use"))
  end

  it "deletes an unused category" do
    category = create(:category)

    expect { described_class.call(category: category) }.to change(Category, :count).by(-1)
  end

  it "rejects deleting a category with child categories" do
    category = create(:category)
    create(:category, parent: category)

    expect_delete_rejected(category)
  end

  it "rejects deleting a category with products" do
    category = create(:category)
    create(:product, category: category)

    expect_delete_rejected(category)
  end

  it "rejects deleting a category with alternative groups" do
    category = create(:category)
    create(:product_alternative_group, category: category)

    expect_delete_rejected(category)
  end
end
