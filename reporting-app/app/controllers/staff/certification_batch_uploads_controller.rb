# frozen_string_literal: true

module Staff
  class CertificationBatchUploadsController < StaffController
    before_action :set_batch_upload, only: [ :show, :process_batch, :results ]

    # GET /staff/certification_batch_uploads
    def index
      @batch_uploads = CertificationBatchUpload.includes(:uploader).recent
    end

    # GET /staff/certification_batch_uploads/new
    def new
      @batch_upload = CertificationBatchUpload.new
    end

    # POST /staff/certification_batch_uploads
    def create
      uploaded_file = params[:csv_file]

      if uploaded_file.blank?
        flash[:alert] = "Please select a CSV file to upload"
        @batch_upload = CertificationBatchUpload.new
        render :new, status: :unprocessable_entity
        return
      end

      @batch_upload = CertificationBatchUpload.new(
        filename: uploaded_file.original_filename,
        uploader: current_user
      )
      @batch_upload.file.attach(uploaded_file)

      if @batch_upload.save
        flash[:notice] = "File uploaded successfully. You can now process it from the queue."
        redirect_to certification_batch_uploads_path
      else
        flash[:alert] = "Failed to upload file: #{@batch_upload.errors.full_messages.join(', ')}"
        render :new, status: :unprocessable_entity
      end
    end

    # GET /staff/certification_batch_uploads/:id
    def show
    end

    # GET /staff/certification_batch_uploads/:id/results
    def results
      certification_origin = CertificationOrigin.from_batch_upload(@batch_upload.id)
      @certifications = Certification.where(id: certification_origin.select(:certification_id))
      @member_statuses = @certifications.map {|cert| { cert.id => MemberStatusService.determine(cert) } }.reduce({}, :merge)
      @compliant_certifications = @certifications.select { |cert| @member_statuses[cert.id].status == MemberStatus::COMPLIANT }
      @exempt_certifications = @certifications.select { |cert| @member_statuses[cert.id].status == MemberStatus::EXEMPT }
      @member_action_required_certifications = @certifications.select { |cert| [MemberStatus::NOT_COMPLIANT, MemberStatus::AWAITING_REPORT].include?(@member_statuses[cert.id].status) }
      @pending_review_certifications = @certifications.select { |cert| @member_statuses[cert.id].status == MemberStatus::PENDING_REVIEW }
      set_certifications_to_show
      @certification_cases = CertificationCase.where(certification_id: @certifications_to_show.map(&:id)).index_by(&:certification_id)
    end

    # POST /staff/certification_batch_uploads/:id/process_batch
    def process_batch
      unless @batch_upload.processable?
        flash[:alert] = "This batch cannot be processed. Current status: #{@batch_upload.status}"
        redirect_to certification_batch_upload_path(@batch_upload)
        return
      end

      ProcessCertificationBatchUploadJob.perform_later(@batch_upload.id)

      flash[:notice] = "Processing started for #{@batch_upload.filename}. Results will be available shortly."
      redirect_to certification_batch_uploads_path
    end

    private

    def set_batch_upload
      @batch_upload = CertificationBatchUpload.includes(:uploader).find(params[:id])
    end

    def set_certifications_to_show
      case params[:filter]
      when "compliant"
        @certifications_to_show = @compliant_certifications
      when "exempt"
        @certifications_to_show = @exempt_certifications
      when "member_action_required"
        @certifications_to_show = @member_action_required_certifications
      when "pending_review"
        @certifications_to_show = @pending_review_certifications
      else
        @certifications_to_show = @certifications
      end
    end
  end
end
