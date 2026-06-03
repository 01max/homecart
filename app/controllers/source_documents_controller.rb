# Handles user-facing receipt source uploads.
#
# The controller keeps HTTP concerns local: loading dropdown choices, validating
# required form fields, and shaping redirects/renders. Upload persistence,
# content hashing, deduplication, attachment, and job enqueueing stay in
# ReceiptIngestion::UploadService.
class SourceDocumentsController < ApplicationController
  helper_method :store_option_label

  before_action :load_form_options, only: %i[new create]

  def new; end

  def create
    form_errors = upload_form_errors
    return render_new_with_alert(form_errors) if form_errors.any?

    result = ReceiptIngestion::UploadService.call(
      file: upload_params[:file],
      store: selected_store,
      parser_format: selected_parser_format
    )

    redirect_to result.source_document,
                notice: t(result.duplicate ? ".duplicate" : ".success")
  rescue ReceiptIngestion::UploadService::UnsupportedMimeTypeError => e
    render_new_with_alert([ e.message ])
  rescue ActiveRecord::RecordInvalid => e
    render_new_with_alert(e.record.errors.full_messages)
  end

  def show
    @source_document = SourceDocument.find(params[:id])
  end

  private

  def load_form_options
    @stores = Store.includes(:retail_brand).sort_by do |store|
      [ store.retail_brand.name, store.location_name, store.channel ]
    end
    @parser_formats = SourceDocument::PARSER_FORMATS.values
    @selected_store_id = upload_params[:store_id]
    @selected_parser_format = selected_parser_format
    @accepted_mime_types = ReceiptIngestion::UploadService::SUPPORTED_MIME_TYPES.join(",")
  end

  def upload_params
    @upload_params ||= params.fetch(:source_document, ActionController::Parameters.new).permit(
      :file,
      :store_id,
      :parser_format
    )
  end

  def upload_form_errors
    [
      missing_file_error,
      missing_store_error,
      missing_parser_format_error
    ].compact
  end

  def missing_file_error
    return if upload_params[:file].present?

    t(".errors.missing_file")
  end

  def missing_store_error
    return if selected_store.present?

    t(".errors.missing_store")
  end

  def missing_parser_format_error
    return if @parser_formats.include?(selected_parser_format)

    t(".errors.missing_parser_format")
  end

  def selected_store
    return if upload_params[:store_id].blank?

    @selected_store ||= Store.find_by(id: upload_params[:store_id])
  end

  def selected_parser_format
    upload_params[:parser_format]
  end

  def store_option_label(store)
    t(
      "source_documents.form.store_option",
      brand: store.retail_brand.name,
      location: store.location_name,
      channel: store.channel
    )
  end

  def render_new_with_alert(messages)
    flash.now[:alert] = messages.join(" ")
    render :new, status: :unprocessable_entity
  end
end
