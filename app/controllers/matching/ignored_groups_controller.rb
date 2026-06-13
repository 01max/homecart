module Matching
  # Applies an ignore decision to every currently eligible line in a queue group.
  class IgnoredGroupsController < ApplicationController
    def create
      ensure_expected_receipt_line_ids!

      current_preview.receipt_lines.each do |receipt_line|
        ReceiptLineMatching::IgnoreLineService.call(receipt_line: receipt_line)
      end

      redirect_to matching_queue_path,
                  notice: t(
                    "matching.ignored_groups.create.success",
                    count: current_preview.affected_count,
                    label: current_preview.representative_label
                  )
    rescue ArgumentError
      redirect_to matching_queue_path, alert: t("matching.ignored_groups.create.errors.stale_preview")
    end

    private

    def ignored_group_params
      params.require(:ignored_group).permit(:normalized_label, receipt_line_ids: [])
    end

    def current_preview
      @current_preview ||= ReceiptLineMatching::BulkConfirmService.preview(
        normalized_label: ignored_group_params[:normalized_label]
      )
    end

    def ensure_expected_receipt_line_ids!
      return if expected_receipt_line_ids.present? && expected_receipt_line_ids == current_receipt_line_ids

      raise ArgumentError
    end

    def expected_receipt_line_ids
      @expected_receipt_line_ids ||= Array(ignored_group_params[:receipt_line_ids]).filter_map(&:presence).map(&:to_s).sort
    end

    def current_receipt_line_ids
      current_preview.receipt_line_ids.map(&:to_s).sort
    end
  end
end
