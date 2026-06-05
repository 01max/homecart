require "rails_helper"

RSpec.describe "evidence routes", type: :routing do
  it "does not expose source document mutation routes" do
    expect(get: "/source_documents/source-document-id/edit").not_to be_routable
    expect(patch: "/source_documents/source-document-id").not_to be_routable
    expect(put: "/source_documents/source-document-id").not_to be_routable
    expect(delete: "/source_documents/source-document-id").not_to be_routable
  end

  it "does not expose text extraction routes" do
    expect(get: "/text_extractions/text-extraction-id/edit").not_to be_routable
    expect(patch: "/text_extractions/text-extraction-id").not_to be_routable
    expect(put: "/text_extractions/text-extraction-id").not_to be_routable
    expect(delete: "/text_extractions/text-extraction-id").not_to be_routable
  end
end
