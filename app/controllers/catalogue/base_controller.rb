module Catalogue
  # Shared helpers for catalogue management controllers.
  class BaseController < ApplicationController
    private

    def assign_catalogue_identity(record, name)
      record.name = name
      record.normalized_name = ProductCatalog::NormalizeTextService.call(name)
      record.slug = name.to_s.parameterize
    end

    def blank_to_nil(value)
      value.presence
    end

    def redirect_with_record_errors(path, record)
      redirect_to path, alert: record.errors.full_messages.to_sentence
    end
  end
end
