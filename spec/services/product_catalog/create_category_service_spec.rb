require "rails_helper"

RSpec.describe ProductCatalog::CreateCategoryService do
  it "creates a root category with normalized identity fields" do
    category = described_class.call(name: "Épicerie sucrée")

    expect(category).to have_attributes(
      name: "Épicerie sucrée",
      normalized_name: "epicerie sucree",
      slug: "epicerie-sucree",
      parent: nil
    )
  end

  it "creates a nested category under the provided parent" do
    parent = create(:category)

    category = described_class.call(name: "Compotes", parent: parent)

    expect(category.parent).to eq(parent)
    expect(parent.children).to contain_exactly(category)
  end

  it "rejects duplicate normalized category names" do
    described_class.call(name: "Compotes")

    expect { described_class.call(name: "Compotés") }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
