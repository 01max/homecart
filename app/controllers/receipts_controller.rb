# Lists parsed receipts for review and browsing.
#
# The index is intentionally query-only: it applies a parser-status filter when
# the request carries one of the known enum values, then renders receipts newest
# first by purchase time.
class ReceiptsController < ApplicationController
  helper_method :parser_status_label, :receipt_line_kind_label, :receipts_stream_name, :store_label, :unit_of_measure_label

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
      redirect_to edit_receipt_path(@receipt), notice: t(".success")
    else
      prepare_review_form
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def load_receipt
    @receipt = Receipt
               .includes(:text_extraction, :receipt_lines, store: :retail_brand)
               .find(params[:id])
  end

  def prepare_review_form
    @stores = Store.includes(:retail_brand).sort_by { |store| [ store.retail_brand.name, store.location_name, store.channel ] }
    @receipt.receipt_lines.build(position: next_receipt_line_position) unless @receipt.receipt_lines.any?(&:new_record?)
  end

  def next_receipt_line_position
    @receipt.receipt_lines.reject(&:marked_for_destruction?).filter_map(&:position).max.to_i + 1
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
      ]
    )
  end
end
