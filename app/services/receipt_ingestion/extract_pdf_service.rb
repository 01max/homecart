require "open3"

module ReceiptIngestion
  class ExtractPdfService < ApplicationService
    ENGINE = "pdftotext-layout"

    Error = Class.new(StandardError)
    Result = Data.define(:text, :engine)

    def initialize(pdf_path:, command_runner: Open3.method(:capture3))
      @pdf_path = pdf_path
      @command_runner = command_runner
    end

    def call
      stdout, stderr, status = command_runner.call("pdftotext", "-layout", pdf_path.to_s, "-")
      raise Error, error_message(stderr) unless status.success?

      text = stdout.to_s
      raise Error, "pdftotext returned empty text" if text.blank?

      Result.new(text: text, engine: ENGINE)
    end

    private

    attr_reader :pdf_path, :command_runner

    def error_message(stderr)
      detail = stderr.to_s.strip
      return "pdftotext failed" if detail.blank?

      "pdftotext failed: #{detail}"
    end
  end
end
