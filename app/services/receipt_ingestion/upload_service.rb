require "digest"

module ReceiptIngestion
  # Creates immutable source documents from uploaded receipt files.
  #
  # The service owns MIME validation, SHA-256 content hashing, exact-file
  # deduplication, Active Storage attachment, and enqueueing the first
  # background job in the receipt pipeline.
  class UploadService < ApplicationService
    SUPPORTED_MIME_TYPES = SourceDocument::MIME_TYPES.values.freeze

    UnsupportedMimeTypeError = Class.new(StandardError)
    Result = Data.define(:source_document, :duplicate)

    # @param file [#path, #content_type, #original_filename] uploaded file-like object
    # @param store [Store] user-selected store for the source document
    # @param parser_format [String] dotted parser format selected at upload time
    # @param job_class [Class] job class used to continue source-document processing
    # @param broadcaster [Class] service that broadcasts UI pipeline state
    # @param clock [#call] clock dependency returning the ingestion timestamp
    def initialize(
      file:,
      store:,
      parser_format:,
      job_class: Receipt::ProcessSourceDocumentJob,
      broadcaster: BroadcastProcessingStatusService,
      clock: -> { Time.current }
    )
      @file = file
      @store = store
      @parser_format = parser_format
      @job_class = job_class
      @broadcaster = broadcaster
      @clock = clock
    end

    # @return [Result] source document plus whether it was an exact duplicate
    # @raise [UnsupportedMimeTypeError] when the uploaded file type is unsupported
    def call
      validate_mime_type!

      content_hash = calculate_content_hash
      existing_source_document = SourceDocument.find_by(content_hash: content_hash)

      return Result.new(source_document: existing_source_document, duplicate: true) if existing_source_document

      source_document = create_source_document(content_hash)
      job_class.perform_later(source_document)
      broadcaster.call(source_document: source_document, extraction_state: "queued", parsing_state: "waiting")

      Result.new(source_document: source_document, duplicate: false)
    end

    private

    attr_reader :file, :store, :parser_format, :job_class, :broadcaster, :clock

    def validate_mime_type!
      return if SUPPORTED_MIME_TYPES.include?(file.content_type)

      raise UnsupportedMimeTypeError,
            I18n.t(
              "receipt_ingestion.upload.errors.unsupported_mime_type",
              mime_type: file.content_type,
              supported_types: SUPPORTED_MIME_TYPES.join(", ")
            )
    end

    def calculate_content_hash
      rewind_file
      Digest::SHA256.file(file.path).hexdigest
    ensure
      rewind_file
    end

    def create_source_document(content_hash)
      SourceDocument.create!(
        store: store,
        content_hash: content_hash,
        mime_type: file.content_type,
        parser_format: parser_format,
        ingested_at: clock.call,
        original_file: {
          io: file,
          filename: file.original_filename,
          content_type: file.content_type
        }
      )
    end

    def rewind_file
      file.rewind if file.respond_to?(:rewind)
    end
  end
end
