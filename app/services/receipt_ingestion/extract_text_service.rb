module ReceiptIngestion
  class ExtractTextService < ApplicationService
    IMAGE_FAILURE_ENGINE = "tesseract-fra-psm6"
    UNSUPPORTED_MIME_TYPE_ENGINE = "unsupported"

    MissingOriginalFileError = Class.new(StandardError)
    UnsupportedMimeTypeError = Class.new(StandardError)

    def initialize(
      source_document:,
      pdf_extractor: ExtractPdfService,
      image_extractor: ExtractImageWithTesseractService,
      clock: -> { Time.current }
    )
      @source_document = source_document
      @pdf_extractor = pdf_extractor
      @image_extractor = image_extractor
      @clock = clock
    end

    def call
      raise MissingOriginalFileError, "source document has no original file" unless source_document.original_file.attached?

      source_document.original_file.open do |file|
        result = extract(file.path)
        create_successful_text_extraction(result)
      end
    rescue *handled_failure_errors => e
      create_failed_text_extraction(e)
    end

    private

    attr_reader :source_document, :pdf_extractor, :image_extractor, :clock

    def extract(path)
      if source_document.mime_type_pdf?
        pdf_extractor.call(pdf_path: path)
      elsif source_document.mime_type_png? || source_document.mime_type_jpeg?
        image_extractor.call(image_path: path)
      else
        raise UnsupportedMimeTypeError, "unsupported MIME type: #{source_document.mime_type}"
      end
    end

    def create_successful_text_extraction(result)
      TextExtraction.create!(
        source_document: source_document,
        engine: result.engine,
        text: result.text,
        ran_at: clock.call,
        success: true
      )
    end

    def create_failed_text_extraction(error)
      TextExtraction.create!(
        source_document: source_document,
        engine: failure_engine,
        text: "",
        ran_at: clock.call,
        success: false,
        error_message: error.message
      )
    end

    def failure_engine
      if source_document.mime_type_pdf?
        return pdf_extractor::ENGINE if pdf_extractor.const_defined?(:ENGINE)

        return ExtractPdfService::ENGINE
      end

      return IMAGE_FAILURE_ENGINE if source_document.mime_type_png? || source_document.mime_type_jpeg?

      UNSUPPORTED_MIME_TYPE_ENGINE
    end

    def handled_failure_errors
      [
        MissingOriginalFileError,
        UnsupportedMimeTypeError,
        ExtractPdfService::ExtractionError,
        ExtractImageWithTesseractService::ExtractionError
      ]
    end
  end
end
