# Lists parsed receipts for review and browsing.
#
# The index is intentionally query-only: it applies a parser-status filter when
# the request carries one of the known enum values, then renders receipts newest
# first by purchase time.
class ReceiptsController < ApplicationController
  helper_method :parser_status_label, :receipt_line_kind_label, :receipt_line_option_label,
    :receipt_payment_category_label, :receipt_promotion_kind_label, :receipt_promotion_linking_method_label,
    :receipt_promotion_unit_label, :receipts_stream_name, :store_label, :unit_of_measure_label

  before_action :load_receipt, only: %i[edit update]

  def index
    @parser_statuses = Receipt.parser_statuses.keys
    @selected_parser_status = selected_parser_status
    @receipts = filtered_receipts
  end

  def edit
    prepare_review_form
  end

  def update
    if @receipt.update(receipt_params)
      render_successful_update
    else
      prepare_review_form
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def load_receipt
    @receipt = Receipt
               .includes(:text_extraction, :receipt_lines, :receipt_promotions, :receipt_payments, store: :retail_brand)
               .find(params[:id])
  end

  def prepare_review_form
    @stores = Store.includes(:retail_brand).sort_by { |store| [ store.retail_brand.name, store.location_name, store.channel ] }
    @receipt.receipt_lines.build(position: next_receipt_line_position) unless @receipt.receipt_lines.any?(&:new_record?)
    @receipt.receipt_promotions.build unless @receipt.receipt_promotions.any?(&:new_record?)
    @receipt.receipt_payments.build(position: next_receipt_payment_position) unless @receipt.receipt_payments.any?(&:new_record?)
  end

  def next_receipt_line_position
    @receipt.receipt_lines.reject(&:marked_for_destruction?).filter_map(&:position).max.to_i + 1
  end

  def next_receipt_payment_position
    @receipt.receipt_payments.reject(&:marked_for_destruction?).filter_map(&:position).max.to_i + 1
  end

  def render_successful_update
    return redirect_to edit_receipt_path(@receipt), notice: t(".success") unless turbo_frame_request?

    prepare_review_form
    @review_form_notice = t(".success")
    render :edit
  end

  def filtered_receipts
    receipts = Receipt.includes(store: :retail_brand).recent_first
    return receipts unless @selected_parser_status

    receipts.where(parser_status: @selected_parser_status)
  end

  def selected_parser_status
    parser_status = params[:parser_status].presence
    parser_status if Receipt.parser_statuses.key?(parser_status)
  end

  def parser_status_label(parser_status)
    t("receipts.parser_statuses.#{parser_status}")
  end

  def receipt_line_kind_label(kind)
    t("receipts.receipt_line_kinds.#{kind}")
  end

  def receipt_line_option_label(line)
    t("receipts.edit.promotions.linked_line_option", position: line.position, label: line.label)
  end

  def receipt_payment_category_label(category)
    t("receipts.receipt_payment_categories.#{category}")
  end

  def receipt_promotion_kind_label(kind)
    t("receipts.receipt_promotion_kinds.#{kind}")
  end

  def receipt_promotion_linking_method_label(linking_method)
    t("receipts.receipt_promotion_linking_methods.#{linking_method}")
  end

  def receipt_promotion_unit_label(unit)
    t("receipts.receipt_promotion_units.#{unit}")
  end

  def receipts_stream_name(parser_status)
    ReceiptIngestion::BroadcastProcessingStatusService.receipts_stream_name(parser_status)
  end

  def store_label(store)
    t(
      "receipts.store_label",
      brand: store.retail_brand.name,
      location: store.location_name,
      channel: store.channel
    )
  end

  def unit_of_measure_label(unit_of_measure)
    t("receipts.unit_of_measures.#{unit_of_measure}")
  end

  def receipt_params
    params.require(:receipt).permit(
      :store_id,
      :purchased_at,
      :register_number,
      :ticket_number,
      :cashier_code,
      :total_cents,
      :declared_article_count,
      receipt_lines_attributes: [
        :id,
        :position,
        :raw_text,
        :label,
        :quantity,
        :unit_of_measure,
        :unit_price_cents,
        :total_cents,
        :kind,
        :tr_eligible,
        :section_label,
        :_destroy
      ],
      receipt_promotions_attributes: [
        :id,
        :program,
        :unit,
        :delta,
        :label,
        :linked_line_id,
        :kind,
        :linking_method,
        :_destroy
      ],
      receipt_payments_attributes: [
        :id,
        :position,
        :raw_label,
        :category,
        :amount_cents,
        :_destroy
      ]
    )
  end
end
