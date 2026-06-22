require "rails_helper"
require "fileutils"
require "tmpdir"

RSpec.describe RetailCatalog::LoadLocationSeedsService do
  let(:seed_directory) { Pathname.new(Dir.mktmpdir) }

  after do
    FileUtils.remove_entry(seed_directory)
  end

  it "loads tracked retail brands and stores" do
    described_class.call(default_path: tracked_seed_path)

    expect(retailer_a_brand).to have_attributes(name: "Retailer A", aliases: [ "Retailer A" ])
    expect(location_01_store.identifiers).to eq("corpus_label" => "retailer-a-location-01")
  end

  it "merges local private hints into tracked anonymized stores" do
    described_class.call(default_path: tracked_detector_seed_path, local_path: local_private_hints_seed_path)

    expect_private_brand_metadata
    expect_private_store_identifiers
  end

  it "allows local seed data to add private-only stores" do
    described_class.call(default_path: tracked_empty_seed_path, local_path: local_private_store_seed_path)

    expect(private_drive_store.retail_brand.slug).to eq("retailer-a")
    expect(private_drive_store.identifiers).to eq("receipt_store_codes" => [ "9999" ])
  end

  it "rejects invalid detector-friendly identifier shapes" do
    expect { described_class.call(default_path: invalid_identifier_shape_seed_path) }
      .to raise_error(ArgumentError, /receipt_header_patterns/)
  end

  it "rejects unknown default parser formats" do
    expect { described_class.call(default_path: invalid_parser_format_seed_path) }
      .to raise_error(ArgumentError, /default_parser_format/)
  end

  def tracked_seed_path
    write_seed_file("default.yml", brands: [ retailer_a_seed ], stores: [ tracked_store_seed ])
  end

  def tracked_detector_seed_path
    write_seed_file("default.yml", brands: [ retailer_a_seed ], stores: [ tracked_detector_store_seed ])
  end

  def tracked_empty_seed_path
    write_seed_file("default.yml", brands: [ retailer_a_seed ], stores: [])
  end

  def local_private_hints_seed_path
    write_seed_file("local.yml", brands: [ private_retailer_a_seed ], stores: [ local_private_hints_store_seed ])
  end

  def local_private_store_seed_path
    write_seed_file("local.yml", stores: [ private_store_seed ])
  end

  def invalid_identifier_shape_seed_path
    write_seed_file("default.yml", brands: [ retailer_a_seed ], stores: [ invalid_identifier_shape_store_seed ])
  end

  def invalid_parser_format_seed_path
    write_seed_file("default.yml", brands: [ retailer_a_seed ], stores: [ invalid_parser_format_store_seed ])
  end

  def retailer_a_seed
    { name: "Retailer A", slug: "retailer-a", aliases: [ "Retailer A" ] }
  end

  def private_retailer_a_seed
    { name: "Private Retailer A", slug: "retailer-a", aliases: [ "Private Retailer A" ] }
  end

  def tracked_store_seed
    store_seed(identifiers: { corpus_label: "retailer-a-location-01" })
  end

  def tracked_detector_store_seed
    store_seed(
      identifiers: {
        corpus_label: "retailer-a-location-01",
        receipt_header_patterns: [ "RETAILER A LOCATION 01" ],
        detection_hints: { channel_markers: [ "ANON" ] }
      }
    )
  end

  def local_private_hints_store_seed
    store_seed(
      identifiers: {
        default_parser_format: "leclerc.paper.v1",
        receipt_header_patterns: [ "PRIVATE HEADER" ],
        receipt_store_codes: "1234",
        legal_entities: "PRIVATE ENTITY",
        detection_hints: { channel_markers: [ "PRIVATE" ] },
        private_detection_hints: { cashier_names: [ "PRIVATE CASHIER" ] }
      }
    )
  end

  def private_store_seed
    store_seed(location_name: "Private Location", channel: "drive", identifiers: { receipt_store_codes: [ "9999" ] })
  end

  def invalid_identifier_shape_store_seed
    store_seed(identifiers: { receipt_header_patterns: { invalid: true } })
  end

  def invalid_parser_format_store_seed
    store_seed(identifiers: { default_parser_format: "retailer.paper.v9" })
  end

  def store_seed(location_name: "Location 01", channel: "physical", identifiers: {})
    {
      brand_slug: "retailer-a",
      location_name: location_name,
      channel: channel,
      identifiers: identifiers
    }
  end

  def retailer_a_brand
    RetailBrand.find_by!(slug: "retailer-a")
  end

  def location_01_store
    Store.find_by!(retail_brand: retailer_a_brand, location_name: "Location 01", channel: "physical")
  end

  def private_drive_store
    Store.find_by!(location_name: "Private Location", channel: "drive")
  end

  def expect_private_brand_metadata
    expect(retailer_a_brand).to have_attributes(
      name: "Private Retailer A",
      aliases: [ "Retailer A", "Private Retailer A" ]
    )
  end

  def expect_private_store_identifiers
    expect(location_01_store.identifiers).to include(expected_private_identifier_subset)
    expect(location_01_store.identifiers["receipt_header_patterns"]).to eq([ "RETAILER A LOCATION 01", "PRIVATE HEADER" ])
    expect(location_01_store.identifiers["detection_hints"]).to eq("channel_markers" => [ "ANON", "PRIVATE" ])
  end

  def expected_private_identifier_subset
    {
      "corpus_label" => "retailer-a-location-01",
      "default_parser_format" => "leclerc.paper.v1",
      "receipt_store_codes" => [ "1234" ],
      "legal_entities" => [ "PRIVATE ENTITY" ],
      "private_detection_hints" => { "cashier_names" => [ "PRIVATE CASHIER" ] }
    }
  end

  def write_seed_file(filename, content)
    path = seed_directory.join(filename)
    path.write(content.deep_stringify_keys.to_yaml)
    path
  end
end
