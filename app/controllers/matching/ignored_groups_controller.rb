module Matching
  # Applies an ignore decision to every currently eligible line in a queue group.
  class IgnoredGroupsController < ApplicationController
    def create
      ensure_expected_count!

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
      params.require(:ignored_group).permit(:normalized_label, :expected_count)
    end

    def current_preview
      @current_preview ||= ReceiptLineMatching::BulkConfirmService.preview(
        normalized_label: ignored_group_params[:normalized_label]
      )
    end

    def ensure_expected_count!
      return if ignored_group_params[:expected_count].to_i == current_preview.affected_count

      raise ArgumentError
    end
  end
end
