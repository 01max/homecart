default_retail_seed_path = Rails.root.join("db/seeds/retail_locations.yml")
local_retail_seed_path = Rails.root.join("db/seeds/retail_locations.local.yml")

RetailCatalog::LoadLocationSeedsService.call(
  default_path: default_retail_seed_path,
  local_path: local_retail_seed_path
)
