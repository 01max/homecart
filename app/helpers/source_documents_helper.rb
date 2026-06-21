module SourceDocumentsHelper
  def source_document_classification_stores
    Store.includes(:retail_brand).sort_by do |store|
      [ store.retail_brand.name, store.location_name, store.channel ]
    end
  end

  def source_document_classification_store_options(stores = source_document_classification_stores)
    stores.map do |store|
      [ store_option_label(store), store.id ]
    end
  end

  def source_document_parser_format_options
    SourceDocument::PARSER_FORMATS.values
  end

  def store_option_label(store)
    t(
      "source_documents.form.store_option",
      brand: store.retail_brand.name,
      location: store.location_name,
      channel: store.channel
    )
  end
end
