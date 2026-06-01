require "yaml"

default_retail_seed_path = Rails.root.join("db/seeds/retail_locations.yml")
local_retail_seed_path = Rails.root.join("db/seeds/retail_locations.local.yml")

retail_seed_path = local_retail_seed_path.exist? ? local_retail_seed_path : default_retail_seed_path
retail_seed_data = YAML.safe_load_file(retail_seed_path, aliases: false)

brands_by_slug = retail_seed_data.fetch("brands").each_with_object({}) do |attributes, collection|
  brand = RetailBrand.find_or_initialize_by(slug: attributes.fetch("slug"))
  brand.update!(
    name: attributes.fetch("name"),
    aliases: attributes.fetch("aliases", [])
  )
  collection[brand.slug] = brand
end

retail_seed_data.fetch("stores").each do |attributes|
  brand = brands_by_slug.fetch(attributes.fetch("brand_slug"))
  store = Store.find_or_initialize_by(
    retail_brand: brand,
    location_name: attributes.fetch("location_name"),
    channel: attributes.fetch("channel")
  )

  store.update!(
    address: attributes["address"],
    identifiers: attributes.fetch("identifiers", {})
  )
end
