require "open3"

module ReceiptIngestion
  class ExtractPdfService < ApplicationService
    ENGINE = "pdftotext-layout"

    ExtractionError = Class.new(StandardError)
    Result = Data.define(:text, :engine)

    def initialize(pdf_path:, command_runner: Open3.method(:capture3))
      @pdf_path = pdf_path
      @command_runner = command_runner
    end

    def call
      stdout, stderr, status = command_runner.call("pdftotext", "-layout", pdf_path.to_s, "-")
      raise ExtractionError, error_message(stderr) unless status.success?

      text = stdout.to_s
      raise ExtractionError, I18n.t("receipt_ingestion.extract_pdf.errors.empty_text") if text.blank?

      Result.new(text: text, engine: ENGINE)
    end

    private

    attr_reader :pdf_path, :command_runner

    def error_message(stderr)
      detail = stderr.to_s.strip
      return I18n.t("receipt_ingestion.extract_pdf.errors.failed") if detail.blank?

      I18n.t("receipt_ingestion.extract_pdf.errors.failed_with_detail", detail: detail)
    end
  end
end
