# frozen_string_literal: true

module Staff
  class CertificationBatchUploadsController < StaffController
    before_action :set_batch_upload, only: [ :show, :process_batch, :results ]
    after_action :verify_authorized # TODO: Move to StaffController in follow-up PR

    # GET /staff/certification_batch_uploads
    def index
      authorize CertificationBatchUpload
      @batch_uploads = CertificationBatchUpload.includes(:uploader).recent
    end

    # GET /staff/certification_batch_uploads/new
    def new
      authorize CertificationBatchUpload
      @batch_upload = CertificationBatchUpload.new
    end

    # POST /staff/certification_batch_uploads
    def create
      authorize CertificationBatchUpload
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

    # GET /staff/certification_batch_uploads/:id
    def show
      authorize @batch_upload
    end

    # GET /staff/certification_batch_uploads/:id/results
    def results
      authorize @batch_upload
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
      authorize @batch_upload
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

    def set_batch_upload
      @batch_upload = CertificationBatchUpload.includes(:uploader).find(params[:id])
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
  end
end
