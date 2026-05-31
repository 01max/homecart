# frozen_string_literal: true

require "fileutils"
require "pathname"
require "rtesseract"

ROOT = Pathname.new(__dir__).join("..").expand_path
OUTPUT_DIR = ROOT.join("tmp/ocr_spike")
PREPROCESSED_DIR = OUTPUT_DIR.join("preprocessed")

Receipt = Data.define(:path, :notes, :expectations)
Expectation = Data.define(:label, :pattern)

def expectation(label, pattern)
  Expectation.new(label:, pattern:)
end

RECEIPTS = [
  Receipt.new(
    path: "raw_data/AUCHAN/32ED808C-350E-4FE0-B1C6-CDD8EB920373.png",
    notes: "Short Selfscan receipt, two items, WAAOH payment split.",
    expectations: [
      expectation("store", /VILLENEUVE SUR LOT/),
      expectation("phone", /Téléphone: 05\.53\.49\.62\.00/),
      expectation("date", /Le 31 janvier 2026 à 15:18:32/),
      expectation("register and ticket", /Caisse : 134 Ticket : 43997/),
      expectation("selfscan start", /Début Selfscan/),
      expectation("first item", /ST MICHEL COCOTTE\.\.\s+3,06/),
      expectation("second item", /DELICHOC COOKIES \.\.\s+2,33/),
      expectation("selfscan end", /Fin Selfscan/),
      expectation("total", /Total 5,39 €/),
      expectation("vat gross", /Brut 0,28 5,11 5,39/),
      expectation("waaoh payment", /Reçu WAAOH! 0,56/),
      expectation("card payment", /Reçu CARTE BANCAIRE 4,83/),
      expectation("article count", /2 Articles/)
    ]
  ),
  Receipt.new(
    path: "raw_data/AUCHAN/048F207F-40F4-4D9E-9091-04914E066C99.png",
    notes: "Medium Selfscan receipt with quantity notation and a scan warning.",
    expectations: [
      expectation("store", /VILLENEUVE SUR LOT/),
      expectation("phone", /Téléphone: 05\.53\.49\.62\.00/),
      expectation("date", /Le 03 septembre 2025 à 09:07:24/),
      expectation("register and ticket", /Caisse : 140 Ticket : 81382/),
      expectation("selfscan start", /Début Selfscan/),
      expectation("quantity item", /KLEENEX MOUC MAX P\.\.\s+2\*2,99 5,98/),
      expectation("weighted item", /BANANE JAUNE VRAC 1,02/),
      expectation("selfscan end", /Fin Selfscan/),
      expectation("total", /Total 17,72 €/),
      expectation("vat gross", /Brut 2,42 15,30 17,72/),
      expectation("card payment", /Reçu CARTE BANCAIRE 17,72/),
      expectation("article count", /8 Articles/),
      expectation("scan warning", /Nouveau scan incorrect/)
    ]
  ),
  Receipt.new(
    path: "raw_data/AUCHAN/2FE4C30A-8E5C-4456-A9C5-9B47D6C11026.png",
    notes: "Large Selfscan receipt with discounts, split card payments, and warnings.",
    expectations: [
      expectation("store", /VILLENEUVE SUR LOT/),
      expectation("phone", /Téléphone: 05\.53\.49\.62\.00/),
      expectation("date", /Le 14 mars 2026 à 10:49:09/),
      expectation("register and ticket", /Caisse : 136 Ticket : 31495/),
      expectation("selfscan start", /Début Selfscan/),
      expectation("first item", /COCORETTE OEUFS P\.\.\s+4,64/),
      expectation("middle item", /EMMENTAL BLOC LE KG 4,89/),
      expectation("discount total", /TOTAL REMISES -11,23/),
      expectation("total", /Total 110,30 €/),
      expectation("vat gross", /Brut 7,78 102,52 110,30/),
      expectation("voucher payment", /Reçu BON BRA 5,00/),
      expectation("first card payment", /Reçu CARTE BANCAIRE 25,00/),
      expectation("second card payment", /Reçu CARTE BANCAIRE 80,30/),
      expectation("article count", /36 Articles/),
      expectation("partial warning", /Lecture partielle incorrecte/)
    ]
  ),
  Receipt.new(
    path: "raw_data/AUCHAN/D425EF1D-1E15-401A-A7DE-59320AF9BBB1.png",
    notes: "Large Selfscan receipt with household goods, discounts, and two card payments.",
    expectations: [
      expectation("store", /VILLENEUVE SUR LOT/),
      expectation("phone", /Téléphone: 05\.53\.49\.62\.00/),
      expectation("date", /Le 13 septembre 2025 à 09:50:52/),
      expectation("register and ticket", /Caisse : 136 Ticket : 21373/),
      expectation("selfscan start", /Début Selfscan/),
      expectation("weighted item", /BANANE JAUNE VRAC 2,15/),
      expectation("baby item", /AUCHAN BABY CULOTT\.\.\s+10,99/),
      expectation("discount total", /TOTAL REMISES -5,06/),
      expectation("total", /Total 123,89 €/),
      expectation("vat gross", /Brut 11,98 111,91 123,89/),
      expectation("reduction payment", /Reçu BON DE REDUCTION 0,15/),
      expectation("first card payment", /Reçu CARTE BANCAIRE 25,00/),
      expectation("second card payment", /Reçu CARTE BANCAIRE 98,36/),
      expectation("article count", /41 Articles/),
      expectation("partial warning", /Lecture partielle sans problèmes/)
    ]
  ),
  Receipt.new(
    path: "raw_data/AUCHAN/DB3A2840-E6DE-4C1E-B504-6D709E639543.png",
    notes: "Very large Selfscan receipt with many repeated produce lines and split tenders.",
    expectations: [
      expectation("store", /VILLENEUVE SUR LOT/),
      expectation("phone", /Téléphone: 05\.53\.49\.62\.00/),
      expectation("date", /Le 18 avril 2026 à 12:04:19/),
      expectation("register and ticket", /Caisse : 140 Ticket : 13016/),
      expectation("selfscan start", /Début Selfscan/),
      expectation("first item", /LANOUVELLE AGRI 1\.\.\s+5,15/),
      expectation("baby item", /AUCHAN BABY CULOTT\.\.\s+10,99/),
      expectation("discount total", /TOTAL REMISES -8,81/),
      expectation("total", /Total 150,44 €/),
      expectation("vat gross", /Brut 10,67 139,77 150,44/),
      expectation("waaoh voucher", /Reçu BON WAAOH! 0,08/),
      expectation("waaoh payment", /Reçu WAAOH! 0,90/),
      expectation("large card payment", /Reçu CARTE BANCAIRE 123,56/),
      expectation("article count", /59 Articles/),
      expectation("partial warning", /Lecture partielle sans problèmes/)
    ]
  )
].freeze

PREPROCESS_ARGS = [
  "-colorspace", "Gray",
  "-deskew", "40%",
  "-auto-level",
  "-contrast-stretch", "0x8%",
  "-threshold", "62%"
].freeze

def ocr_text(path)
  RTesseract.new(path.to_s, lang: "fra", psm: 6).to_s
end

def preprocess(source)
  FileUtils.mkdir_p(PREPROCESSED_DIR)
  destination = PREPROCESSED_DIR.join(source.basename)
  command = [ "magick", source.to_s, *PREPROCESS_ARGS, destination.to_s ]
  system(*command, exception: true)
  destination
end

def score(text, expectations)
  misses = expectations.reject { |expectation| text.match?(expectation.pattern) }
  [ expectations.count - misses.count, expectations.count, misses ]
end

FileUtils.mkdir_p(OUTPUT_DIR)

puts "| Receipt | Variant | Matched fields | Accuracy | Missed fields |"
puts "| --- | --- | ---: | ---: | --- |"

RECEIPTS.each do |receipt|
  source = ROOT.join(receipt.path)
  variants = {
    "raw" => source,
    "preprocessed" => preprocess(source)
  }

  variants.each do |variant, image_path|
    text = ocr_text(image_path)
    OUTPUT_DIR.join("#{source.basename(".png")}-#{variant}.txt").write(text)
    matched, total, misses = score(text, receipt.expectations)
    missed_fields = misses.map(&:label).join(", ")
    missed_fields = "-" if missed_fields.empty?
    accuracy = (matched.to_f / total * 100).round(1)

    puts "| #{source.basename} | #{variant} | #{matched}/#{total} | #{accuracy}% | #{missed_fields} |"
  end
end

puts
puts "OCR text output written to #{OUTPUT_DIR.relative_path_from(ROOT)}"
