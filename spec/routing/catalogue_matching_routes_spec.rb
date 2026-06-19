require "rails_helper"

RSpec.describe "catalogue and matching routes", type: :routing do
  it "routes catalogue screen entry points" do
    expect(get: "/catalogue").to route_to("catalogue/dashboard#index")
    expect(get: "/catalogue/categories").to route_to("catalogue/categories#index")
    expect(get: "/catalogue/products").to route_to("catalogue/products#index")
    expect(get: "/catalogue/product_variants").to route_to("catalogue/product_variants#index")
  end

  it "routes matching screen entry points" do
    expect(get: "/matching").to route_to("matching/queue#index")
    expect(get: "/matching/queue").to route_to("matching/queue#index")
    expect(get: "/matching/receipts/receipt-id").to route_to("matching/receipts#show", id: "receipt-id")
  end

  it "routes grouped matching actions" do
    expect(post: "/matching/bulk_confirmations").to route_to("matching/bulk_confirmations#create")
    expect(post: "/matching/ignored_groups").to route_to("matching/ignored_groups#create")
  end

  it "routes matching receipt-line decision actions" do
    expect(post: "/matching/receipt_lines/line-id/confirm").to route_to("matching/receipt_lines#confirm", id: "line-id")
    expect(post: "/matching/receipt_lines/line-id/create_variant").to route_to("matching/receipt_lines#create_variant", id: "line-id")
    expect(post: "/matching/receipt_lines/line-id/ignore").to route_to("matching/receipt_lines#ignore", id: "line-id")
    expect(post: "/matching/receipt_lines/line-id/reject").to route_to("matching/receipt_lines#reject", id: "line-id")
  end
end
