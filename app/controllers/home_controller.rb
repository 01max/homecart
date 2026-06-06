class HomeController < ApplicationController
  def index
    @source_document_count = SourceDocument.count
    @receipt_count = Receipt.count
    @needs_review_count = Receipt.needs_review.count
    @recent_receipts = Receipt.includes(store: :retail_brand).recent_first.limit(5)
    @recent_source_documents = SourceDocument.includes(store: :retail_brand).order(ingested_at: :desc, id: :desc).limit(5)
  end

  def ping
    @pinged_at = Time.current

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to root_path, notice: I18n.t("home.ping.ready") }
    end
  end
end
