require "rails_helper"

RSpec.describe Category do
  it "owns child categories" do
    parent = create(:category)
    child = create(:category, parent: parent)

    expect(parent.children).to contain_exactly(child)
    expect(child.parent).to eq(parent)
  end

  it "owns products and alternative groups" do
    category = create(:category)
    product = create(:product, category: category)
    alternative_group = create(:product_alternative_group, category: category)

    expect(category.products).to contain_exactly(product)
    expect(category.product_alternative_groups).to contain_exactly(alternative_group)
  end

  it "requires a unique normalized name" do
    create(:category, normalized_name: "compotes")
    duplicate = build(:category, normalized_name: "compotes")

    expect(duplicate).not_to be_valid
  end

  it "requires a unique slug" do
    create(:category, slug: "compotes")
    duplicate = build(:category, slug: "compotes")

    expect(duplicate).not_to be_valid
  end

  it "rejects self-parenting" do
    category = create(:category)
    category.parent = category

    expect(category).not_to be_valid
  end
end
