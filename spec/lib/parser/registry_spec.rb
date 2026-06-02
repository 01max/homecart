require "rails_helper"

RSpec.describe Parser::Registry do
  def stub_parser(name)
    stub_const(name, Class.new)
  end

  it "registers and looks up a parser by dotted format" do
    parser_class = stub_parser("Parser::Leclerc::Paper::V2")

    described_class.register("leclerc.paper.v2", parser_class)

    expect(described_class.for("leclerc.paper.v2")).to eq(parser_class)
  end

  it "uses MagasinsU as the Ruby namespace for U parser formats" do
    parser_class = stub_parser("Parser::MagasinsU::Paper::V1")

    described_class.register("u.paper.v1", parser_class)

    expect(described_class.for("u.paper.v1")).to eq(parser_class)
  end

  it "rejects formats outside the canonical registry list" do
    parser_class = stub_parser("Parser::Unknown::Paper::V1")

    expect { described_class.register("unknown.paper.v1", parser_class) }
      .to raise_error(described_class::FormatError, "unknown parser format: unknown.paper.v1")
  end

  it "rejects parser constants that do not mirror the format hierarchy" do
    parser_class = stub_parser("Parsers::LeclercPaperV2")

    expect { described_class.register("leclerc.paper.v2", parser_class) }
      .to raise_error(described_class::NamespaceError, /Parser::Leclerc::Paper::V2/)
  end

  it "raises a clear error for unregistered parser formats" do
    expect { described_class.for("leclerc.paper.v1") }
      .to raise_error(described_class::UnknownFormatError, "no parser registered for leclerc.paper.v1")
  end

  it "is the canonical source for model parser format values" do
    expect(SourceDocument::PARSER_FORMATS).to equal(described_class::FORMATS)
  end
end
