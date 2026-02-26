# app/controllers/document_staging_controller.rb
class DocumentStagingController < ApplicationController
  ALLOWED_CONTENT_TYPES    = %w[application/pdf image/jpeg].freeze
  MAX_FILE_SIZE_BYTES       = 30.megabytes
  MAX_FILE_COUNT            = 2
  SUPPORTED_RESULT_CLASSES = [DocAiResult::Payslip, DocAiResult::W2].freeze

  # Dedicated thread pool for DocAI processing — isolates upload concurrency from
  # the concurrent-ruby global IO pool so burst upload traffic cannot starve other
  # consumers (e.g., ActiveStorage callbacks). Pool size = MAX_FILE_COUNT × 2
  # concurrent requests, tunable via configuration if needed.
  DOC_AI_THREAD_POOL = Concurrent::FixedThreadPool.new(
    Rails.application.config.doc_ai.fetch(:thread_pool_size, MAX_FILE_COUNT * 2)
  )

  def create
    authorize :document, :create?

    files = Array(params[:files])
    if files.empty?
      flash.now[:alert] = t(".no_files")
      return render :create, status: :unprocessable_entity
    end
    if files.size > MAX_FILE_COUNT
      flash.now[:alert] = t(".too_many_files", max: MAX_FILE_COUNT)
      return render :create, status: :unprocessable_entity
    end

    @results = process_files_concurrently(files)
    render :create  # renders create.html.erb with @results
  end

  private

  # Dispatches each file to a Concurrent::Future so all DocAI calls run in parallel.
  # Total wall-clock time ≈ one DocAI call (~38s) regardless of file count.
  #
  # Futures execute on DOC_AI_THREAD_POOL (a dedicated FixedThreadPool) rather than
  # the concurrent-ruby global IO pool, isolating DocAI concurrency from the rest of
  # the application. current_user is captured before threading because controller
  # helpers are not thread-safe. Each Future checks out its own DB connection via
  # with_connection to avoid contention on the request thread's connection.
  def process_files_concurrently(files)
    user = current_user  # capture — controller helpers are not thread-safe

    futures = files.map do |file|
      Concurrent::Future.execute(executor: DOC_AI_THREAD_POOL) do
        ActiveRecord::Base.connection_pool.with_connection do
          process_file(file, user: user)
        end
      end
    end

    futures.map do |future|
      future.value!  # re-raises any exception from the thread
    rescue StandardError => e
      Rails.logger.error("[DocumentStagingController] concurrent processing error: #{e.message}")
      { file: nil, error: t(".analysis_unavailable"), staged_document: nil }
    end
  end

  def process_file(file, user:)
    unless valid_content_type?(file)
      return { file: file, error: t(".invalid_content_type"), staged_document: nil }
    end
    unless valid_file_size?(file)
      return { file: file, error: t(".file_too_large"), staged_document: nil }
    end

    staged_document = StagedDocument.new(user: user, status: :pending)
    staged_document.file.attach(file)
    staged_document.save!  # validates :file, attached: true before committing — no orphaned records
    result = DocAiService.new.analyze(file: staged_document.file)

    if result.nil?
      staged_document.update!(status: :failed)
      return { file: file, error: t(".analysis_unavailable"), staged_document: staged_document }
    end

    unless SUPPORTED_RESULT_CLASSES.any? { |klass| result.is_a?(klass) }
      staged_document.update!(status: :rejected)
      return { file: file, error: t(".unrecognised_document"), staged_document: staged_document }
    end

    staged_document.update!(
      status:               :validated,
      doc_ai_job_id:        result.job_id,
      doc_ai_matched_class: result.matched_document_class,
      extracted_fields:     result.fields,
      validated_at:         Time.current
    )

    sid = staged_document.signed_id(expires_in: 1.hour)
    { file: file, staged_document: staged_document, signed_id: sid, result: result }
  end

  # Server-side content-type validation using Marcel (magic-byte detection).
  # Does not trust the browser-reported Content-Type header, which can be spoofed.
  # Marcel is already a Rails dependency via ActiveStorage.
  def valid_content_type?(file)
    detected = Marcel::MimeType.for(file.tempfile, name: file.original_filename)
    detected.in?(ALLOWED_CONTENT_TYPES)
  end

  def valid_file_size?(file) = file.size <= MAX_FILE_SIZE_BYTES
end
