module ReceiptIngestion
  class ExtractTextService < ApplicationService
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
        create_text_extraction(result)
      end
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

    def create_text_extraction(result)
      TextExtraction.create!(
        source_document: source_document,
        engine: result.engine,
        text: result.text,
        ran_at: clock.call,
        success: true
      )
    end
  end
end
