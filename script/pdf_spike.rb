# frozen_string_literal: true

require "fileutils"
require "open3"
require "pathname"
require "pdf-reader"

ROOT = Pathname.new(__dir__).join("..").expand_path
OUTPUT_DIR = ROOT.join("tmp/pdf_spike")

Receipt = Data.define(:path, :format, :notes, :expectations)
Expectation = Data.define(:label, :pattern)

def expectation(label, pattern)
  Expectation.new(label:, pattern:)
end

RECEIPTS = [
  Receipt.new(
    path: "raw_data/LECLERC/E.Leclerc - Ticket du 05.10.2024.pdf",
    format: "leclerc.paper.v1",
    notes: "Old paper format with optional section markers, quantity lines, card loyalty, and vignettes.",
    expectations: [
      expectation("store", /VILLENEUVE\/LOT/),
      expectation("phone", /TEL:05\.53\.01\.58\.58/),
      expectation("register and date", /Caisse\s+001-0102\s+05\s+octobre\s+2024\s+16:45/),
      expectation("ticket id", /05\/10\/24\s+0\s+01A9\s+0DT00/),
      expectation("section marker", />>\s+EPICERIE/),
      expectation("item label", /PAIN\s+COMPLET\s+PROTEINE\s+BIO\s+250G/),
      expectation("quantity line", /3\s+X\s+3\.54€\s+10\.62/),
      expectation("total", /Total\s+13\s+articles\s+35\.83/),
      expectation("payment", /^ *CB\s+35\.83/m),
      expectation("loyalty detail", /Détail\s+des\s+avantages\s+obtenus/),
      expectation("leclerc balance", /CUMUL\s+DISPONIBLE\s+AU\s+06\/10\/24\s+:\s+1\.34\s+€/),
      expectation("vignettes", /Vous\s+venez\s+d'obtenir\s+:\s+3\s+Vignette\(s\)/)
    ]
  ),
  Receipt.new(
    path: "raw_data/LECLERC/E.Leclerc - Ticket du 04.04.2025.pdf",
    format: "leclerc.paper.v2",
    notes: "New paper format with per-line VAT code and `Code HT TVA TTC` table.",
    expectations: [
      expectation("store", /VILLENEUVE\/LOT/),
      expectation("phone", /TEL:05\.53\.01\.58\.58/),
      expectation("register and date", /Caisse\s+304-3004\s+04\s+avril\s+2025\s+12:56/),
      expectation("ticket id", /Ticket\s+04\/04\/25\s+8\s+8P95\s+02Y00/),
      expectation("item label", /COLLANT\s+H13\s+W1147\s+NOIR\s+T2/),
      expectation("quantity line", /2\s+X\s+5\.35€\s+10\.70\s+3/),
      expectation("total", /Total\s+2\s+articles\s+10\.70/),
      expectation("payment", /^ *CB\s+10\.70/m),
      expectation("vat table header", /Code\s+HT\s+TVA\s+TTC/),
      expectation("vat table line", /3\s+20%00\s+8\.92\s+1\.78\s+10\.70/),
      expectation("card timestamp", /le\s+04\/04\/25\s+a\s+12:56:58/),
      expectation("card amount", /MONTANT\s+=\s+10,70\s+EUR/)
    ]
  ),
  Receipt.new(
    path: "raw_data/LECLERC/E.Leclerc - Ticket du 20.04.2025.pdf",
    format: "leclerc.web.v1",
    notes: "Drive web format with a delivery fee line.",
    expectations: [
      expectation("store", /E\.Leclerc\s+PARISDIF/),
      expectation("register and date", /Caisse\s+Drive\s+700-7999\s+-\s+20\s+avr\.\s+2025/),
      expectation("order code", /3\s+K00C\s+JJI00/),
      expectation("first item", /BIO\s+COURGETTE\s+LONGUE\s+BIOVILLAGE\s+2\.29/),
      expectation("quantity item", /2\s+X\s+THON\s+SAVX\s+H\.\s+OLIVE\s+160G\s+5\.89/),
      expectation("delivery fee", /FRAIS\s+DE\s+LIVRAISON\s+A\s+5\.5%\s+11\.90/),
      expectation("total", /Total\s+25\s+articles\s+68\.60/),
      expectation("payment", /CB\s+Web\s+Drive\s+68\.60/),
      expectation("web detail notice", /Retrouvez\s+le\s+détail\s+de\s+votre\s+commande/)
    ]
  )
].freeze

def pdf_reader_text(path)
  PDF::Reader.new(path.to_s).pages.map(&:text).join("\n")
end

def pdftotext_text(path)
  stdout, stderr, status = Open3.capture3("pdftotext", "-layout", path.to_s, "-")
  raise "pdftotext failed for #{path}: #{stderr}" unless status.success?

  stdout
end

def score(text, expectations)
  comparable_text = text.tr("\u00A0", " ")
  misses = expectations.reject { |expectation| comparable_text.match?(expectation.pattern) }
  [ expectations.count - misses.count, expectations.count, misses ]
end

FileUtils.mkdir_p(OUTPUT_DIR)

puts "| Receipt | Format | Engine | Matched fields | Accuracy | Missed fields |"
puts "| --- | --- | --- | ---: | ---: | --- |"

RECEIPTS.each do |receipt|
  source = ROOT.join(receipt.path)
  engines = {
    "pdf-reader" => pdf_reader_text(source),
    "pdftotext -layout" => pdftotext_text(source)
  }

  engines.each do |engine, text|
    output_path = OUTPUT_DIR.join("#{source.basename(".pdf")}-#{engine.tr(" -", "_")}.txt")
    output_path.write(text)

    matched, total, misses = score(text, receipt.expectations)
    missed_fields = misses.map(&:label).join(", ")
    missed_fields = "-" if missed_fields.empty?
    accuracy = (matched.to_f / total * 100).round(1)

    puts "| #{source.basename} | #{receipt.format} | #{engine} | #{matched}/#{total} | #{accuracy}% | #{missed_fields} |"
  end
end

puts
puts "PDF text output written to #{OUTPUT_DIR.relative_path_from(ROOT)}"
