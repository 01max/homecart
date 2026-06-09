require "rails_helper"

RSpec.describe ProductCatalog::UpdateCategoryService do
  it "renames a category and refreshes normalized identity fields" do
    category = create(:category, name: "Compotes")

    result = described_class.call(category: category, name: "Goûter", parent: nil)

    expect(result).to have_attributes(name: "Goûter", normalized_name: "gouter", slug: "gouter")
  end

  it "moves a category under a new parent" do
    parent = create(:category)
    category = create(:category)

    result = described_class.call(category: category, name: nil, parent: parent)

    expect(result.parent).to eq(parent)
    expect(parent.children).to contain_exactly(category)
  end

  it "rejects moving a category under its descendant" do
    root = create(:category)
    child = create(:category, parent: root)

    expect do
      described_class.call(category: root, name: nil, parent: child)
    end.to raise_error(ActiveRecord::StatementInvalid)
  end
end
