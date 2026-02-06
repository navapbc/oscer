# frozen_string_literal: true

module Staff
  class CertificationBatchUploadsController < AdminController
    self.authorization_resource = CertificationBatchUpload

    before_action :set_batch_upload, only: [ :show, :process_batch, :results ]

    # GET /staff/certification_batch_uploads
    def index
      @batch_uploads = policy_scope(CertificationBatchUpload).includes(:uploader).recent
    end

    # GET /staff/certification_batch_uploads/new
    def new
      @batch_upload = CertificationBatchUpload.new
    end

    # POST /staff/certification_batch_uploads/presigned_url
    def presigned_url
      unless feature_enabled?(:batch_upload_v2)
        head :not_found
        return
      end

      authorize CertificationBatchUpload, :create?

      filename = params[:filename]

      if filename.blank?
        render json: { error: t("staff.certification_batch_uploads.presigned_url.filename_required") }, status: :unprocessable_content
        return
      end

      unless filename.end_with?(".csv")
        render json: { error: t("staff.certification_batch_uploads.presigned_url.csv_only") }, status: :unprocessable_content
        return
      end

      sanitized_filename = sanitize_filename(filename)
      result = SignedUrlService.new.generate_upload_url(filename: sanitized_filename, content_type: "text/csv")

      render json: { url: result[:url], key: result[:key] }
    end

    # POST /staff/certification_batch_uploads
    def create
      # Determine if we're using v2 flow (flag enabled + storage_key present)
      use_v2_flow = feature_enabled?(:batch_upload_v2) && params[:storage_key].present?

      if use_v2_flow
        create_with_v2_flow
      else
        create_with_v1_flow
      end
    end

    # GET /staff/certification_batch_uploads/:id
    def show
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

    # POST /staff/certification_batch_uploads/:id/process_batch
    def process_batch
      respond_to do |format|
        if @batch_upload.processable? == false
          message = "This batch cannot be processed. Current status: #{@batch_upload.status}."
          format.html { redirect_to certification_batch_upload_path(@batch_upload), alert: message }
          format.json { render json: { error: message }, status: :unprocessable_content }
        elsif ProcessCertificationBatchUploadJob.perform_later(@batch_upload.id)
          format.html { redirect_to certification_batch_uploads_path, notice: "Processing started for #{@batch_upload.filename}. Results will be available shortly." }
          format.json { head :accepted }
        else
          format.html { redirect_to certification_batch_upload_path(@batch_upload), alert: "Failed to start processing job." }
          format.json { render json: { error: "Failed to start processing job." }, status: :internal_server_error }
        end
      end
    end

    private

    def create_with_v2_flow
      storage_key = params[:storage_key]
      filename = params[:filename]

      # Validate storage key format to prevent path traversal
      unless storage_key&.match?(%r{\Abatch-uploads/[0-9a-f-]{36}/[^/]+\z})
        respond_to do |format|
          format.html { redirect_to new_certification_batch_upload_path, alert: t("staff.certification_batch_uploads.create_with_v2_flow.invalid_storage_key") }
          format.json { render json: { error: "Invalid storage key format" }, status: :unprocessable_content }
        end
        return
      end

      sanitized_filename = sanitize_filename(filename)

      begin
        @batch_upload = CertificationBatchUploadOrchestrator.new.initiate(
          source_type: :ui,
          filename: sanitized_filename,
          storage_key: storage_key,
          uploader: current_user
        )

        respond_to do |format|
          format.html { redirect_to certification_batch_upload_path(@batch_upload), notice: "File uploaded successfully and processing has started." }
          format.json { render :show, status: :created, location: @batch_upload }
        end
      rescue CertificationBatchUploadOrchestrator::FileNotFoundError => e
        respond_to do |format|
          format.html { redirect_to new_certification_batch_upload_path, alert: t("staff.certification_batch_uploads.create_with_v2_flow.file_not_found") }
          format.json { render json: { error: e.message }, status: :unprocessable_content }
        end
      end
    end

    def create_with_v1_flow
      uploaded_file = params[:csv_file]

      if uploaded_file.blank?
        flash.now[:alert] = "Please select a CSV file to upload"
        @batch_upload = CertificationBatchUpload.new
        render :new, status: :unprocessable_content
        return
      end

      @batch_upload = CertificationBatchUpload.new(
        filename: uploaded_file.original_filename,
        uploader: current_user
      )
      @batch_upload.file.attach(uploaded_file)

      respond_to do |format|
        if @batch_upload.save
          format.html { redirect_to certification_batch_uploads_path, notice: "File uploaded successfully. You can now process it from the queue." }
          format.json { render :show, status: :created, location: @batch_upload }
        else
          message = "Failed to upload file: #{@batch_upload.errors.full_messages.join(', ')}"
          format.html { redirect_to new_certification_batch_upload_path, alert: message }
          format.json { render json: { error: message }, status: :unprocessable_content }
        end
      end
    end

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

    def sanitize_filename(filename)
      return nil if filename.blank?
      # Remove null bytes first (File.basename raises on null bytes)
      clean_filename = filename.tr("\x00", "")
      # Remove path components, replace spaces with underscores, limit length
      File.basename(clean_filename)
        .gsub(/\s+/, "_")           # Replace spaces with underscores
        .gsub(/[^\w.-]/, "_")       # Replace other unsafe chars
        .truncate(255, omission: "")
    end
  end
end
