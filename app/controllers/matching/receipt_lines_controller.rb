module Matching
  # Handles one-line matching decisions from the matching queue.
  class ReceiptLinesController < ApplicationController
    before_action :load_receipt_line
    before_action :load_product_variant, only: %i[confirm reject]

    def confirm
      ReceiptLineMatching::ConfirmMatchService.call(receipt_line: @receipt_line, product_variant: @product_variant)

      redirect_to decision_redirect_path,
                  notice: t("matching.receipt_lines.confirm.success", label: @receipt_line.label)
    end

    def create_variant
      result = ProductCatalog::CreateVariantService.call(
        product_brand_name: inline_product_variant_params[:product_brand_name],
        product_name: inline_product_variant_params[:product_name],
        variant_name: inline_product_variant_params[:variant_name],
        category: inline_category,
        retail_brand: inline_retail_brand,
        manufacturer_name: inline_product_variant_params[:manufacturer_name],
        comparison_unit: inline_comparison_unit,
        package_count: blank_to_nil(inline_product_variant_params[:package_count]),
        quantity_value: blank_to_nil(inline_product_variant_params[:quantity_value]),
        barcode: blank_to_nil(inline_product_variant_params[:barcode])
      )
      ReceiptLineMatching::ConfirmMatchService.call(receipt_line: @receipt_line, product_variant: result.variant)

      redirect_to decision_redirect_path,
                  notice: t("matching.receipt_lines.create_variant.success", variant: result.variant.name, label: @receipt_line.label)
    rescue ActiveRecord::RecordInvalid => e
      redirect_to decision_redirect_path, alert: e.record.errors.full_messages.to_sentence
    rescue ActiveRecord::RecordNotFound
      redirect_to decision_redirect_path,
                  alert: t("matching.receipt_lines.create_variant.errors.category_required")
    end

    def ignore
      ReceiptLineMatching::IgnoreLineService.call(receipt_line: @receipt_line)

      redirect_to decision_redirect_path,
                  notice: t("matching.receipt_lines.ignore.success", label: @receipt_line.label)
    end

    def reject
      ReceiptLineMatching::RejectMatchService.call(receipt_line: @receipt_line, product_variant: @product_variant)

      redirect_to decision_redirect_path,
                  notice: t("matching.receipt_lines.reject.success", label: @receipt_line.label)
    end

    private

    def load_receipt_line
      @receipt_line = ReceiptLine.find(params[:id])
    end

    def load_product_variant
      @product_variant = ProductVariant.find(params.require(:product_variant_id))
    end

    def inline_product_variant_params
      params.require(:inline_product_variant).permit(
        :product_brand_name,
        :retail_brand_id,
        :product_name,
        :category_id,
        :manufacturer_name,
        :variant_name,
        :comparison_unit_id,
        :package_count,
        :quantity_value,
        :barcode
      )
    end

    def inline_category
      raise ActiveRecord::RecordNotFound if inline_product_variant_params[:category_id].blank?

      Category.find(inline_product_variant_params[:category_id])
    end

    def inline_retail_brand
      return if inline_product_variant_params[:retail_brand_id].blank?

      RetailBrand.find(inline_product_variant_params[:retail_brand_id])
    end

    def inline_comparison_unit
      return if inline_product_variant_params[:comparison_unit_id].blank?

      ComparisonUnit.find(inline_product_variant_params[:comparison_unit_id])
    end

    def blank_to_nil(value)
      value.presence
    end

    def decision_redirect_path
      url_from(params[:return_to]) || matching_queue_path
    end
  end
end
