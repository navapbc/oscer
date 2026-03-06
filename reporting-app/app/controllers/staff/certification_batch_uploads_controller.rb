# frozen_string_literal: true

require "csv"

module Staff
  class CertificationBatchUploadsController < AdminController
    self.authorization_resource = CertificationBatchUpload
    MAX_DISPLAYED_ERRORS = 100

    before_action :set_batch_upload, only: [ :show, :results, :download_errors ]

    # GET /staff/certification_batch_uploads
    def index
      @batch_uploads = policy_scope(CertificationBatchUpload).includes(:uploader).recent
    end

    # GET /staff/certification_batch_uploads/new
    def new
      @batch_upload = CertificationBatchUpload.new
    end

    # POST /staff/certification_batch_uploads
    def create
      create_batch_upload(source_type: :ui)
    end

    # GET /staff/certification_batch_uploads/:id
    def show
      @upload_errors = @batch_upload.upload_errors.order(:row_number).limit(MAX_DISPLAYED_ERRORS)
    end

    # GET /staff/certification_batch_uploads/:id/results
    def results
      certification_origin = CertificationOrigin.from_batch_upload(@batch_upload.id)
      certification_ids = certification_origin.select(:certification_id).map(&:certification_id)

      # Load cases with hydrated certifications to avoid duplicate queries
      certification_service = CertificationService.new
      @certification_cases = certification_service.fetch_cases_by_certification_ids(certification_ids)

      # Determine member statuses using hydrated cases
      @member_statuses = MemberStatusService.determine_many(@certification_cases)

      # Categorize cases by status
      @compliant_cases = @certification_cases.select { |kase| @member_statuses[[ "CertificationCase", kase.id ]].status == MemberStatus::COMPLIANT }
      @exempt_cases = @certification_cases.select { |kase| @member_statuses[[ "CertificationCase", kase.id ]].status == MemberStatus::EXEMPT }
      @member_action_required_cases = @certification_cases.select { |kase| [ MemberStatus::NOT_COMPLIANT, MemberStatus::AWAITING_REPORT ].include?(@member_statuses[[ "CertificationCase", kase.id ]].status) }
      @pending_review_cases = @certification_cases.select { |kase| @member_statuses[[ "CertificationCase", kase.id ]].status == MemberStatus::PENDING_REVIEW }

      set_cases_to_show
    end

    # GET /staff/certification_batch_uploads/:id/download_errors
    def download_errors
      errors = CertificationBatchUploadError
        .where(certification_batch_upload: @batch_upload)
        .order(:row_number)

      csv_data = CSV.generate do |csv|
        csv << [ "Row", "Error Code", "Error Message", "Row Data" ]
        errors.each do |error|
          csv << [ error.row_number, error.error_code, error.error_message, error.row_data&.to_json ]
        end
      end

      send_data csv_data,
                filename: "#{File.basename(@batch_upload.filename, '.*')}_errors.csv",
                type: "text/csv",
                disposition: "attachment"
    end

    private

    def set_batch_upload
      @batch_upload = policy_scope(CertificationBatchUpload).includes(:uploader).find(params[:id])
    end

    def set_cases_to_show
      case params[:filter]
      when "compliant"
        @cases_to_show = @compliant_cases
      when "exempt"
        @cases_to_show = @exempt_cases
      when "member_action_required"
        @cases_to_show = @member_action_required_cases
      when "pending_review"
        @cases_to_show = @pending_review_cases
      else
        @cases_to_show = @certification_cases
      end
    end

    def create_batch_upload(source_type:)
      uploaded_file = params[:csv_file]

      if uploaded_file.blank?
        flash.now[:alert] = "Please select a CSV file to upload"
        @batch_upload = CertificationBatchUpload.new
        render :new, status: :unprocessable_content
        return
      end

      # Direct upload sends a signed blob ID string;
      # no-JS fallback sends an ActionDispatch::Http::UploadedFile
      begin
        filename, attachable = resolve_file_upload(uploaded_file)
      rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
        flash.now[:alert] = "Upload failed. Please try again."
        @batch_upload = CertificationBatchUpload.new
        render :new, status: :unprocessable_content
        return
      end

      @batch_upload = CertificationBatchUpload.new(
        filename: sanitize_filename(filename),
        uploader: current_user,
        source_type: source_type
      )
      @batch_upload.file.attach(attachable)

      return handle_upload_failure unless @batch_upload.save

      handle_upload_success
    end

    def handle_upload_success
      ProcessCertificationBatchUploadJob.perform_later(@batch_upload.id)

      respond_to do |format|
        format.html do
          redirect_to certification_batch_uploads_path,
                      notice: "Processing started for #{@batch_upload.filename}. Results will be available shortly."
        end
        format.json { render :show, status: :created, location: @batch_upload }
      end
    end

    def handle_upload_failure
      message = "Failed to upload file: #{@batch_upload.errors.full_messages.join(', ')}"
      respond_to do |format|
        format.html { redirect_to new_certification_batch_upload_path, alert: message }
        format.json { render json: { error: message }, status: :unprocessable_content }
      end
    end

    # Resolves the filename and attachable object from the file param.
    # Direct upload submits a signed blob ID string (JavaScript-enabled browsers);
    # no-JS fallback submits an ActionDispatch::Http::UploadedFile.
    def resolve_file_upload(uploaded_file)
      if uploaded_file.is_a?(String)
        blob = ActiveStorage::Blob.find_signed!(uploaded_file)
        [ blob.filename.to_s, blob ]
      else
        [ uploaded_file.original_filename, uploaded_file ]
      end
    end

    # Sanitize uploaded filename to prevent path traversal and XSS
    # - Uses ActiveStorage::Filename for Rails-native path component removal and
    #   filesystem character normalization (path separators, RTL markers, shell metacharacters)
    # - Applies strict allowlist to ensure only alphanumeric, hyphen, underscore, period remain
    def sanitize_filename(filename)
      ActiveStorage::Filename.new(File.basename(filename)).sanitized
                             .gsub(/[^\w\-.]/, "_")
    end
  end
end
