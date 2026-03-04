# frozen_string_literal: true

class Api::CertificationBatchUploadsController < ApiController
  before_action :require_batch_upload_v2!

  def create
    create_request = Api::CertificationBatchUploads::CreateRequest.from_request_params(params)

    if create_request.invalid?
      return render_errors(create_request)
    end

    blob = ActiveStorage::Blob.find_signed!(create_request.signed_blob_id)
    filename = sanitize_filename(blob.filename.to_s)

    batch_upload = CertificationBatchUpload.new(
      filename: filename,
      source_type: :api
    )
    batch_upload.file.attach(blob)

    authorize batch_upload

    batch_upload.save!
    ProcessCertificationBatchUploadJob.perform_later(batch_upload.id)

    render_data(
      Api::CertificationBatchUploads::Response.from_batch_upload(batch_upload),
      status: :created
    )
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    render_errors("Invalid or expired signed blob ID", :unprocessable_content)
  rescue ActiveRecord::RecordInvalid => e
    render_errors(e.record)
  end

  def show
    batch_upload = policy_scope(CertificationBatchUpload).find(params[:id])
    authorize batch_upload

    render_data(Api::CertificationBatchUploads::Response.from_batch_upload(batch_upload))
  rescue ActiveRecord::RecordNotFound
    render_errors("Not Found", :not_found)
  end

  private

  def require_batch_upload_v2!
    return if Features.batch_upload_v2_enabled?

    render_errors("Not Found", :not_found)
  end

  def sanitize_filename(filename)
    ActiveStorage::Filename.new(File.basename(filename)).sanitized
                           .gsub(/[^\w\-.]/, "_")
  end
end
