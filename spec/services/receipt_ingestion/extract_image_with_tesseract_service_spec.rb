require "rails_helper"

RSpec.describe ReceiptIngestion::ExtractImageWithTesseractService do
  let(:status) { instance_double(Process::Status, success?: true) }
  let(:version_runner) { ->(*) { [ "tesseract 5.5.1\n", "", status ] } }
  let(:ocr_calls) { [] }
  let(:ocr_text) { { value: "Receipt text\n" } }
  let(:fake_tesseract_client) do
    calls = ocr_calls
    text = ocr_text

    Class.new do
      define_method(:initialize) do |path, options|
        calls << [ path, options ]
      end

      define_method(:to_s) do
        text.fetch(:value)
      end
    end
  end

  def call_service(**options)
    described_class.call(
      image_path: "/tmp/receipt.png",
      ocr_client_class: fake_tesseract_client,
      version_runner: version_runner,
      **options
    )
  end

  it "returns extracted text and the engine identifier" do
    result = call_service

    expect(result.text).to eq("Receipt text\n")
    expect(result.engine).to eq("tesseract-5.5.1-fra-psm6")
  end

  it "extracts text from a fixture PNG" do
    result = described_class.call(image_path: Rails.root.join("spec/fixtures/files/receipt_image.png"))

    expect(result.text).to include("TICKET TEST")
    expect(result.text).to include("TOTAL 12,34 EUR")
    expect(result.engine).to match(/\Atesseract-\d+(?:\.\d+)+-fra-psm6\z/)
  end

  it "runs raw Tesseract with French data and PSM 6" do
    call_service

    expect(ocr_calls).to eq([ [ "/tmp/receipt.png", { lang: "fra", psm: 6 } ] ])
  end

  it "defaults preprocessing to disabled" do
    preprocessor = instance_spy(Proc)

    call_service(preprocessor: preprocessor)

    expect(preprocessor).not_to have_received(:call)
  end

  it "uses an explicit preprocessor when requested" do
    preprocessor = ->(path) { "#{path}.processed.png" }

    call_service(preprocess: true, preprocessor: preprocessor)

    expect(ocr_calls.first.first).to eq("/tmp/receipt.png.processed.png")
  end

  it "raises a service error when preprocessing is requested without a preprocessor" do
    expect { call_service(preprocess: true) }
      .to raise_error(described_class::ExtractionError, "image preprocessing requested but no preprocessor was provided")
  end

  it "raises a service error when Tesseract returns empty text" do
    ocr_text[:value] = ""

    expect { call_service }.to raise_error(described_class::ExtractionError, "tesseract returned empty text")
  end

  it "raises a service error when Tesseract fails" do
    failing_client = Class.new do
      def initialize(*) = nil
      def to_s = raise RTesseract::Error, "bad image"
    end

    expect do
      described_class.call(image_path: "/tmp/receipt.png", ocr_client_class: failing_client, version_runner: version_runner)
    end.to raise_error(described_class::ExtractionError, "tesseract failed: bad image")
  end
end
