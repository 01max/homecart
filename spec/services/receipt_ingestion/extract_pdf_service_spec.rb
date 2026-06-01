require "rails_helper"

RSpec.describe ReceiptIngestion::ExtractPdfService do
  let(:status) { instance_double(Process::Status, success?: true) }

  it "returns extracted text and the engine identifier" do
    runner = ->(*) { [ "Receipt text\n", "", status ] }

    result = described_class.call(pdf_path: Rails.root.join("tmp/example.pdf"), command_runner: runner)

    expect(result.text).to eq("Receipt text\n")
    expect(result.engine).to eq("pdftotext-layout")
  end

  it "extracts text from a fixture PDF" do
    result = described_class.call(pdf_path: Rails.root.join("spec/fixtures/files/receipt_text.pdf"))

    expect(result.text).to include("HOME CART PDF FIXTURE")
    expect(result.text).to include("TOTAL 12,34 EUR")
    expect(result.engine).to eq("pdftotext-layout")
  end

  it "runs pdftotext with layout mode and stdout output" do
    command = nil
    runner = lambda do |*args|
      command = args
      [ "Receipt text\n", "", status ]
    end

    described_class.call(pdf_path: "/tmp/receipt.pdf", command_runner: runner)

    expect(command).to eq([ "pdftotext", "-layout", "/tmp/receipt.pdf", "-" ])
  end

  it "raises a service error when pdftotext fails" do
    failed_status = instance_double(Process::Status, success?: false)
    runner = ->(*) { [ "", "bad PDF", failed_status ] }

    expect { described_class.call(pdf_path: "/tmp/receipt.pdf", command_runner: runner) }
      .to raise_error(described_class::ExtractionError, "pdftotext failed: bad PDF")
  end

  it "raises a service error when pdftotext returns empty text" do
    runner = ->(*) { [ "", "", status ] }

    expect { described_class.call(pdf_path: "/tmp/receipt.pdf", command_runner: runner) }
      .to raise_error(described_class::ExtractionError, "pdftotext returned empty text")
  end
end
