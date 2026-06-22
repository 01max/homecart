module SourceDocumentsHelper
  EVIDENCE_FIELD_ORDER = %w[
    parser_format
    parser_formats
    marker
    store_id
    store_ids
    source
    value
    explicit_parser_format
    detected_parser_formats
    explicit_store_id
    detected_store_ids
  ].freeze

  STORE_EVIDENCE_FIELDS = %w[
    store_id
    store_ids
    explicit_store_id
    detected_store_ids
  ].freeze

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

  def source_document_detection_evidence_label(entry)
    code = entry["code"].presence || "unknown"

    t(
      "source_documents.show.classification.evidence_codes.#{code}",
      default: t("source_documents.show.classification.evidence_codes.unknown", code: code)
    )
  end

  def source_document_detection_evidence_details(entry)
    ordered_evidence_fields(entry).map do |key|
      [
        source_document_detection_evidence_field_label(key),
        source_document_detection_evidence_field_value(key, entry.fetch(key))
      ]
    end
  end

  private

  def ordered_evidence_fields(entry)
    keys = entry.keys - [ "code" ]
    known_keys = EVIDENCE_FIELD_ORDER & keys
    unknown_keys = keys - known_keys

    known_keys + unknown_keys.sort
  end

  def source_document_detection_evidence_field_label(key)
    t(
      "source_documents.show.classification.evidence_fields.#{key}",
      default: t("source_documents.show.classification.evidence_fields.unknown", field: key)
    )
  end

  def source_document_detection_evidence_field_value(key, value)
    return source_document_detection_store_value(value) if STORE_EVIDENCE_FIELDS.include?(key)
    return source_document_detection_source_label(value) if key == "source"
    return source_document_detection_marker_label(value) if key == "marker"

    Array(value).join(", ")
  end

  def source_document_detection_store_value(value)
    ids = Array(value).map(&:to_s)
    stores_by_id = Store.includes(:retail_brand).where(id: ids).index_by { |store| store.id.to_s }

    ids.map { |id| stores_by_id[id] ? store_option_label(stores_by_id[id]) : id }.join(", ")
  end

  def source_document_detection_source_label(source)
    key = source.to_s.tr(".", "_")

    t(
      "source_documents.show.classification.evidence_sources.#{key}",
      default: t("source_documents.show.classification.evidence_sources.unknown", source: source)
    )
  end

  def source_document_detection_marker_label(marker)
    t(
      "source_documents.show.classification.evidence_markers.#{marker}",
      default: t("source_documents.show.classification.evidence_markers.unknown", marker: marker)
    )
  end
end
