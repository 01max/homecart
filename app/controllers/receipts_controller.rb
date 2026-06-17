# Lists parsed receipts for review and browsing.
#
# The index is intentionally query-only: it applies a parser-status filter and
# whitelisted ordering when the request carries known values.
class ReceiptsController < ApplicationController
  INDEX_SORT_COLUMNS = {
    "purchased_at" => {
      default_direction: "desc",
      sorts: {
        "asc" => [ "purchased_at asc", "id asc" ],
        "desc" => [ "purchased_at desc", "id desc" ]
      }
    },
    "store" => {
      default_direction: "asc",
      sorts: {
        "asc" => [ "store_retail_brand_name asc", "store_location_name asc", "store_channel asc", "id asc" ],
        "desc" => [ "store_retail_brand_name desc", "store_location_name desc", "store_channel desc", "id desc" ]
      }
    },
    "parser_status" => {
      default_direction: "asc",
      sorts: {
        "asc" => [ "parser_status_text asc", "id asc" ],
        "desc" => [ "parser_status_text desc", "id desc" ]
      }
    },
    "total" => {
      default_direction: "asc",
      sorts: {
        "asc" => [ "total_cents asc", "id asc" ],
        "desc" => [ "total_cents desc", "id desc" ]
      }
    },
    "parser_format" => {
      default_direction: "asc",
      sorts: {
        "asc" => [ "parser_format_text asc", "id asc" ],
        "desc" => [ "parser_format_text desc", "id desc" ]
      }
    }
  }.freeze

  VALIDATOR_LABEL_KEYS = {
    "validate_totals_sum" => "receipts.edit.validators.totals_sum.label",
    "validate_article_count" => "receipts.edit.validators.article_count.label",
    "validate_payments_sum" => "receipts.edit.validators.payments_sum.label"
  }.freeze

  helper_method :parser_status_label, :receipt_line_kind_label, :receipt_line_option_label,
    :purchased_at_field_value, :receipt_integer_field_value, :receipt_payment_category_label,
    :receipt_promotion_kind_label, :receipt_promotion_linking_method_label, :receipt_promotion_unit_label,
    :receipt_quantity_field_step, :receipt_quantity_field_value, :receipt_total_label, :receipts_stream_name,
    :store_label, :unit_of_measure_label

  before_action :load_receipt, only: %i[show edit update destroy mark_reviewed rerun_parser]

  def index
    @parser_statuses = Receipt.parser_statuses.keys
    @selected_parser_status = selected_parser_status
    @sort_column = receipt_index_sort_column
    @sort_direction = receipt_index_sort_direction(@sort_column)
    @receipts = filtered_receipts
  end

  def edit
    prepare_review_form
  end

  def show
    @matching_queue_entry_count = receipt_matching_queue_entry_count if @receipt.reviewed?
  end

  def update
    if @receipt.update(receipt_params)
      render_successful_update
    else
      prepare_review_form
      render :edit, status: :unprocessable_entity
    end
  end

  def mark_reviewed
    if @receipt.update(reviewed_receipt_params)
      render_review_result(ReceiptIngestion::FinalizeReviewService.call(receipt: @receipt))
    else
      prepare_review_form
      render :edit, status: :unprocessable_entity
    end
  end

  def rerun_parser
    parser_format = rerun_parser_params[:parser_format]
    return render_invalid_parser_format unless SourceDocument::PARSER_FORMATS.values.include?(parser_format)

    ReceiptIngestion::RerunParserService.call(receipt: @receipt, parser_format: parser_format)
    render_successful_rerun
  rescue ReceiptIngestion::RerunParserService::MissingSuccessfulTextExtractionError,
         ReceiptIngestion::DetectDuplicateService::DuplicateReceiptError => e
    add_rerun_error(e.message)
    prepare_review_form
    render :edit, status: :unprocessable_entity
  end

  def destroy
    @receipt.destroy!
    redirect_to receipts_path, notice: t(".success")
  end

  private

  def load_receipt
    @receipt = Receipt
               .includes(:source_document, :text_extraction, :receipt_lines, :receipt_promotions, :receipt_payments, store: :retail_brand)
               .find(params[:id])
  end

  def prepare_review_form
    @stores = Store.includes(:retail_brand).sort_by { |store| [ store.retail_brand.name, store.location_name, store.channel ] }
    @receipt.receipt_lines.build(position: next_receipt_line_position) unless @receipt.receipt_lines.any?(&:new_record?)
    @receipt.receipt_promotions.build unless @receipt.receipt_promotions.any?(&:new_record?)
    @receipt.receipt_payments.build(position: next_receipt_payment_position) unless @receipt.receipt_payments.any?(&:new_record?)
  end

  def receipt_matching_queue_entry_count
    ReceiptLineMatching::ReceiptQueueService.call(receipt: @receipt, persist_suggestions: false).size
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

  def render_review_result(result)
    if result.success?
      render_successful_review
    else
      add_validator_failure_error(result)
      prepare_review_form
      render :edit, status: :unprocessable_entity
    end
  end

  def render_successful_review
    unless turbo_frame_request?
      return redirect_to edit_receipt_path(@receipt), notice: t("receipts.mark_reviewed.success")
    end

    prepare_review_form
    @review_form_notice = t("receipts.mark_reviewed.success")
    render :edit
  end

  def render_successful_rerun
    @receipt.reload
    return redirect_to edit_receipt_path(@receipt), notice: t("receipts.rerun_parser.success") unless turbo_frame_request?

    prepare_review_form
    @review_form_notice = t("receipts.rerun_parser.success")
    render :edit
  end

  def render_invalid_parser_format
    add_rerun_error(t("receipts.rerun_parser.errors.invalid_parser_format"))
    prepare_review_form
    render :edit, status: :unprocessable_entity
  end

  def add_rerun_error(message)
    @receipt.errors.add(:base, message)
  end

  def add_validator_failure_error(result)
    labels = result.failed_validators.map { |validator| t(VALIDATOR_LABEL_KEYS.fetch(validator)) }

    @receipt.errors.add(
      :base,
      t("receipts.mark_reviewed.errors.validators_failed", validators: labels.to_sentence)
    )
  end

  def filtered_receipts
    search = Receipt.includes(:source_document, store: :retail_brand).ransack(receipt_index_ransack_params)
    search.sorts = receipt_index_sorts
    @q = search

    search.result
  end

  def selected_parser_status
    parser_status = params[:parser_status].presence || params.dig(:q, :parser_status_eq).presence
    parser_status if Receipt.parser_statuses.key?(parser_status)
  end

  def receipt_index_sort_column
    sort_column = params[:sort].presence
    INDEX_SORT_COLUMNS.key?(sort_column) ? sort_column : "purchased_at"
  end

  def receipt_index_sort_direction(sort_column)
    direction = params[:direction].presence
    return direction if %w[asc desc].include?(direction)

    INDEX_SORT_COLUMNS.fetch(sort_column).fetch(:default_direction)
  end

  def receipt_index_ransack_params
    ransack_params = params[:q]&.permit(:parser_status_eq) || {}
    ransack_params = ransack_params.to_h
    ransack_params["parser_status_eq"] = @selected_parser_status if @selected_parser_status
    ransack_params
  end

  def receipt_index_sorts
    INDEX_SORT_COLUMNS.fetch(@sort_column).fetch(:sorts).fetch(@sort_direction)
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

  def purchased_at_field_value(receipt)
    receipt.purchased_at&.strftime("%d/%m/%Y %H:%M")
  end

  def receipt_integer_field_value(value)
    value.to_i if value.present?
  end

  def receipt_quantity_field_value(line)
    trimmed_decimal_value(line.quantity)
  end

  def receipt_quantity_field_step(line)
    line.unit_of_measure == "piece" ? "1" : "0.001"
  end

  def receipt_total_label(total_cents)
    return t("receipts.index.empty_value") if total_cents.blank?

    helpers.number_to_currency(total_cents / 100.0, unit: "€", separator: ",", delimiter: " ", format: "%n %u")
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
    ).tap { |permitted_params| normalize_purchased_at_param(permitted_params) }
  end

  def reviewed_receipt_params
    receipt_params.tap do |permitted_params|
      normalize_reviewed_promotion_linking_methods(permitted_params)
    end
  end

  def rerun_parser_params
    params.require(:receipt).permit(:parser_format)
  end

  def normalize_reviewed_promotion_linking_methods(permitted_params)
    promotion_attributes = permitted_params[:receipt_promotions_attributes]
    return unless promotion_attributes

    promotion_attributes.each_value do |attributes|
      next if ActiveModel::Type::Boolean.new.cast(attributes[:_destroy])

      attributes[:linking_method] = if attributes[:linked_line_id].present?
        "user_confirmed"
      else
        "unallocated"
      end
    end
  end

  def normalize_purchased_at_param(permitted_params)
    value = permitted_params[:purchased_at]
    return if value.blank?

    parsed_value = parse_purchased_at_param(value)
    permitted_params[:purchased_at] = parsed_value if parsed_value
  end

  def parse_purchased_at_param(value)
    return value if value.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}\z/)

    match = value.match(/\A(?<day>\d{1,2})\/(?<month>\d{1,2})\/(?<year>\d{4})[ T](?<hour>\d{1,2}):(?<minute>\d{2})\z/)
    return unless match

    Time.zone.local(
      match[:year].to_i,
      match[:month].to_i,
      match[:day].to_i,
      match[:hour].to_i,
      match[:minute].to_i
    )
  rescue ArgumentError
    nil
  end

  def trimmed_decimal_value(value)
    return if value.blank?

    value.to_d.to_s("F").then { |string| string.include?(".") ? string.sub(/0+\z/, "").sub(/\.\z/, "") : string }
  end
end
