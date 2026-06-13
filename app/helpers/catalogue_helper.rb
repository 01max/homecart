module CatalogueHelper
  def catalogue_category_label(category)
    category_breadcrumb_text(category)
  end

  def catalogue_product_brand_label(product_brand)
    if product_brand.retail_brand
      t("product_catalog.labels.private_label_brand", name: product_brand.name, retail_brand: product_brand.retail_brand.name)
    else
      product_brand.name
    end
  end

  def catalogue_product_label(product)
    t(
      "product_catalog.labels.product",
      brand: product.product_brand.name,
      product: product.name,
      category: catalogue_category_label(product.category)
    )
  end

  def catalogue_product_variant_label(product_variant)
    t(
      "product_catalog.labels.variant",
      product: catalogue_product_label(product_variant.product),
      variant: product_variant.name
    )
  end

  def catalogue_comparison_unit_label(comparison_unit)
    return t("product_catalog.labels.empty_value") unless comparison_unit

    t("product_catalog.labels.comparison_unit", name: comparison_unit.name, symbol: comparison_unit.symbol)
  end

  def catalogue_product_options(products)
    products.map { |product| [ catalogue_product_label(product), product.id ] }
  end

  def catalogue_variant_options(product_variants)
    product_variants.map { |variant| [ catalogue_product_variant_label(variant), variant.id ] }
  end
end
