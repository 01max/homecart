# Lists parsed receipts for review and browsing.
#
# The index is intentionally query-only: it applies a parser-status filter when
# the request carries one of the known enum values, then renders receipts newest
# first by purchase time.
class ReceiptsController < ApplicationController
  helper_method :parser_status_label, :receipts_stream_name, :store_label

  before_action :load_receipt, only: %i[edit update]

  def index
    @parser_statuses = Receipt.parser_statuses.keys
    @selected_parser_status = selected_parser_status
    @receipts = filtered_receipts
  end

  def edit; end

  def update
    if @receipt.update(receipt_params)
      redirect_to edit_receipt_path(@receipt), notice: t(".success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def load_receipt
    @receipt = Receipt
               .includes(:text_extraction, :receipt_lines, store: :retail_brand)
               .find(params[:id])
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

  def receipt_params
    params.require(:receipt).permit(
      :purchased_at,
      :register_number,
      :ticket_number,
      :cashier_code,
      :total_cents,
      :declared_article_count
    )
  end
end
