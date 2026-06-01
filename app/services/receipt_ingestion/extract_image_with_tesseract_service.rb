require "open3"
require "rtesseract"

module ReceiptIngestion
  class ExtractImageWithTesseractService < ApplicationService
    LANG = "fra"
    PSM = 6

    ExtractionError = Class.new(StandardError)
    ExtractionResult = Data.define(:text, :engine)

    def initialize(
      image_path:,
      preprocess: false,
      preprocessor: nil,
      ocr_client_class: RTesseract,
      version_runner: Open3.method(:capture3)
    )
      @image_path = image_path
      @preprocess = preprocess
      @preprocessor = preprocessor
      @ocr_client_class = ocr_client_class
      @version_runner = version_runner
    end

    def call
      text = ocr_client_class.new(ocr_path.to_s, lang: LANG, psm: PSM).to_s
      raise ExtractionError, "tesseract returned empty text" if text.blank?

      ExtractionResult.new(text: text, engine: engine_identifier)
    rescue RTesseract::Error => e
      raise ExtractionError, error_message(e.message)
    end

    private

    attr_reader :image_path, :preprocess, :preprocessor, :ocr_client_class, :version_runner

    def ocr_path
      return image_path unless preprocess
      raise ExtractionError, "image preprocessing requested but no preprocessor was provided" unless preprocessor

      preprocessor.call(image_path)
    end

    def engine_identifier
      stdout, stderr, status = version_runner.call("tesseract", "--version")
      raise ExtractionError, error_message(stderr) unless status.success?

      version = stdout.to_s.lines.first.to_s[/\d+(?:\.\d+)+/]
      raise ExtractionError, "could not detect tesseract version" if version.blank?

      "tesseract-#{version}-#{LANG}-psm#{PSM}"
    end

    def error_message(detail)
      detail = detail.to_s.strip
      return "tesseract failed" if detail.blank?

      "tesseract failed: #{detail}"
    end
  end
end
