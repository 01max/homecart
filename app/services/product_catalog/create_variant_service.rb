module ProductCatalog
  # Creates or reuses the catalogue chain needed for one concrete product variant.
  class CreateVariantService < ApplicationService
    Result = Data.define(:product_brand, :manufacturer, :category, :product, :variant, :comparison_unit)

    def initialize(
      product_brand_name:,
      product_name:,
      variant_name:,
      category: nil,
      category_name: nil,
      retail_brand: nil,
      manufacturer: nil,
      manufacturer_name: nil,
      comparison_unit: nil,
      comparison_unit_name: nil,
      comparison_unit_symbol: nil,
      package_count: nil,
      quantity_value: nil,
      barcode: nil
    )
      @product_brand_name = product_brand_name
      @product_name = product_name
      @variant_name = variant_name
      @category = category
      @category_name = category_name
      @retail_brand = retail_brand
      @manufacturer = manufacturer
      @manufacturer_name = manufacturer_name
      @comparison_unit = comparison_unit
      @comparison_unit_name = comparison_unit_name
      @comparison_unit_symbol = comparison_unit_symbol
      @package_count = package_count
      @quantity_value = quantity_value
      @barcode = barcode
    end

    def call
      ApplicationRecord.transaction do
        resolved_category = category_record
        resolved_product_brand = product_brand_record
        resolved_manufacturer = manufacturer_record
        resolved_comparison_unit = comparison_unit_record
        resolved_product = product_record(resolved_product_brand, resolved_category, resolved_manufacturer)
        resolved_variant = variant_record(resolved_product, resolved_comparison_unit)

        Result.new(
          product_brand: resolved_product_brand,
          manufacturer: resolved_manufacturer,
          category: resolved_category,
          product: resolved_product,
          variant: resolved_variant,
          comparison_unit: resolved_comparison_unit
        )
      end
    end

    private

    attr_reader :product_brand_name,
      :product_name,
      :variant_name,
      :category,
      :category_name,
      :retail_brand,
      :manufacturer,
      :manufacturer_name,
      :comparison_unit,
      :comparison_unit_name,
      :comparison_unit_symbol,
      :package_count,
      :quantity_value,
      :barcode

    def category_record
      return category if category.present?

      find_or_create_named_record(Category, category_name)
    end

    def product_brand_record
      find_or_create_named_record(ProductBrand, product_brand_name) do |product_brand|
        product_brand.retail_brand = retail_brand
      end.tap do |product_brand|
        link_retail_brand(product_brand)
      end
    end

    def link_retail_brand(product_brand)
      return if retail_brand.blank? || product_brand.retail_brand == retail_brand
      return product_brand.update!(retail_brand: retail_brand) if product_brand.retail_brand.blank?

      product_brand.errors.add(:retail_brand, :conflict)
      raise ActiveRecord::RecordInvalid, product_brand
    end

    def manufacturer_record
      return manufacturer if manufacturer.present?
      return if manufacturer_name.blank?

      find_or_create_named_record(Manufacturer, manufacturer_name)
    end

    def comparison_unit_record
      return comparison_unit if comparison_unit.present?
      return if comparison_unit_name.blank? && comparison_unit_symbol.blank?

      symbol = normalized_symbol
      ComparisonUnit.find_by(symbol: symbol) ||
        find_or_create_named_record(ComparisonUnit, comparison_unit_name.presence || symbol) do |unit|
          unit.symbol = symbol
        end
    end

    def product_record(product_brand, category, manufacturer)
      Product.find_or_initialize_by(
        product_brand: product_brand,
        category: category,
        normalized_name: normalized(product_name)
      ).tap do |product|
        if product.new_record?
          product.name = product_name
          product.slug = slug(product_name)
        end

        product.manufacturer ||= manufacturer if manufacturer.present?
        product.save!
      end
    end

    def variant_record(product, comparison_unit)
      ProductVariant.find_or_initialize_by(
        product: product,
        normalized_name: normalized(variant_name)
      ).tap do |variant|
        if variant.new_record?
          variant.name = variant_name
          variant.slug = slug(variant_name)
        end

        variant.comparison_unit ||= comparison_unit if comparison_unit.present?
        variant.package_count ||= package_count if package_count.present?
        variant.quantity_value ||= quantity_value if quantity_value.present?
        variant.barcode ||= barcode if barcode.present?
        variant.save!
      end
    end

    def find_or_create_named_record(model_class, name)
      model_class.find_or_create_by!(normalized_name: normalized(name)) do |record|
        record.name = name
        record.slug = slug(name)
        yield(record) if block_given?
      end
    end

    def normalized(value)
      NormalizeTextService.call(value)
    end

    def normalized_symbol
      comparison_unit_symbol.presence || slug(comparison_unit_name)
    end

    def slug(value)
      value.to_s.parameterize
    end
  end
end
