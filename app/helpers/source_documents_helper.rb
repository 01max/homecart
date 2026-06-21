module SourceDocumentsHelper
  def store_option_label(store)
    t(
      "source_documents.form.store_option",
      brand: store.retail_brand.name,
      location: store.location_name,
      channel: store.channel
    )
  end
end
