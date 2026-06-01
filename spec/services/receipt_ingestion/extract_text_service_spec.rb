require "rails_helper"

RSpec.describe ReceiptIngestion::ExtractTextService do
  let(:extraction_result_class) { Data.define(:text, :engine) }

  def attach_original_file(source_document, content_type: source_document.mime_type)
    source_document.original_file.attach(
      io: StringIO.new("file bytes"),
      filename: "receipt",
      content_type: content_type
    )
  end

  def recording_extractor(result)
    calls = []
    extractor = Class.new do
      define_singleton_method(:call) do |**kwargs|
        calls << kwargs
        result
      end
    end

    [ extractor, calls ]
  end

  def failing_extractor(error_class, message)
    Class.new do
      define_singleton_method(:call) do |**|
        raise error_class, message
      end
    end
  end

  def expect_failed_extraction(extraction, engine:, error_message:)
    expect(extraction).to have_attributes(
      text: "",
      engine: engine,
      success: false,
      error_message: error_message
    )
  end

  it "routes PDF source documents and persists a successful text extraction" do
    source_document = create_source_document(mime_type: "application/pdf")
    attach_original_file(source_document)
    pdf_extractor, calls = recording_extractor(extraction_result_class.new("PDF text", "pdftotext-layout"))

    extraction = described_class.call(source_document: source_document, pdf_extractor: pdf_extractor)

    expect(extraction).to have_attributes(text: "PDF text", engine: "pdftotext-layout", success: true)
    expect(calls.first).to include(:pdf_path)
  end

  it "routes image source documents and persists a successful text extraction" do
    source_document = create_source_document(mime_type: "image/png")
    attach_original_file(source_document)
    image_extractor, calls = recording_extractor(extraction_result_class.new("Image text", "tesseract-5.5.1-fra-psm6"))

    extraction = described_class.call(source_document: source_document, image_extractor: image_extractor)

    expect(extraction).to have_attributes(text: "Image text", engine: "tesseract-5.5.1-fra-psm6", success: true)
    expect(calls.first).to include(:image_path)
  end

  it "records the extraction timestamp from the injected clock" do
    source_document = create_source_document
    attach_original_file(source_document)
    pdf_extractor, = recording_extractor(extraction_result_class.new("PDF text", "pdftotext-layout"))
    ran_at = Time.zone.local(2026, 6, 1, 12, 0, 0)

    extraction = described_class.call(source_document: source_document, pdf_extractor: pdf_extractor, clock: -> { ran_at })

    expect(extraction.ran_at).to eq(ran_at)
  end

  it "persists a failed text extraction when PDF extraction fails" do
    source_document = create_source_document(mime_type: "application/pdf")
    attach_original_file(source_document)
    pdf_extractor = failing_extractor(ReceiptIngestion::ExtractPdfService::ExtractionError, "pdftotext failed")

    extraction = described_class.call(source_document: source_document, pdf_extractor: pdf_extractor)

    expect_failed_extraction(extraction, engine: "pdftotext-layout", error_message: "pdftotext failed")
  end

  it "persists a failed text extraction when image extraction fails" do
    source_document = create_source_document(mime_type: "image/png")
    attach_original_file(source_document)
    image_extractor = failing_extractor(
      ReceiptIngestion::ExtractImageWithTesseractService::ExtractionError,
      "tesseract returned empty text"
    )

    extraction = described_class.call(source_document: source_document, image_extractor: image_extractor)

    expect_failed_extraction(extraction, engine: "tesseract-fra-psm6", error_message: "tesseract returned empty text")
  end

  it "persists a failed text extraction when the original file is missing" do
    source_document = create_source_document

    extraction = described_class.call(source_document: source_document)

    expect_failed_extraction(extraction, engine: "pdftotext-layout", error_message: "source document has no original file")
  end
end
