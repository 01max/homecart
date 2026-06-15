require "rails_helper"

RSpec.describe "Theme toggle", type: :request do
  it "renders dark mode controls in the application shell" do
    get root_path

    expect(response.body).to include('data-controller="workspace-nav theme"')
    expect(response.body).to include('data-theme-target="toggle"')
    expect(response.body).to include(I18n.t("app.nav.dark_mode"))
  end
end
