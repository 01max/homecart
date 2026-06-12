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
end
