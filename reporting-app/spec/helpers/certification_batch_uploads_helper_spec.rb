# frozen_string_literal: true

require "rails_helper"

RSpec.describe CertificationBatchUploadsHelper, type: :helper do
  let(:user) { create(:user) }

  describe "#uploader_display_name" do
    it 'returns uploader email for ui-sourced uploads' do
      batch_upload = create(:certification_batch_upload, uploader: user)
      expect(helper.uploader_display_name(batch_upload)).to eq(user.email)
    end

    it 'returns "API" for api-sourced uploads' do
      batch_upload = create(:certification_batch_upload, :api_sourced)
      expect(helper.uploader_display_name(batch_upload)).to eq("API")
    end

    it 'returns "System" for storage_event-sourced uploads' do
      batch_upload = create(:certification_batch_upload, uploader: nil, source_type: :storage_event)
      expect(helper.uploader_display_name(batch_upload)).to eq("System")
    end

    it 'returns "Unknown" for ui-sourced uploads with missing uploader' do
      batch_upload = build(:certification_batch_upload, uploader: nil, source_type: :ui)
      expect(helper.uploader_display_name(batch_upload)).to eq("Unknown")
    end
  end

  describe "#status_alert_options" do
    it "returns info alert for pending uploads" do
      batch_upload = build(:certification_batch_upload, status: :pending)
      result = helper.status_alert_options(batch_upload)

      expect(result[:type]).to eq("info")
      expect(result[:message]).to be_present
      expect(result).not_to have_key(:heading)
    end

    it "returns info alert with progress for processing uploads" do
      batch_upload = build(:certification_batch_upload, :processing)
      result = helper.status_alert_options(batch_upload)

      expect(result[:type]).to eq("info")
      expect(result[:message]).to include("5", "10")
      expect(result).not_to have_key(:heading)
    end

    it "returns error alert with heading for failed uploads" do
      batch_upload = build(:certification_batch_upload, :failed, results: { "error" => "Something broke" })
      result = helper.status_alert_options(batch_upload)

      expect(result[:type]).to eq("error")
      expect(result[:heading]).to be_present
      expect(result[:message]).to eq("Something broke")
    end

    it "returns fallback message when failed upload has no error detail" do
      batch_upload = build(:certification_batch_upload, :failed, results: {})
      result = helper.status_alert_options(batch_upload)

      expect(result[:type]).to eq("error")
      expect(result[:message]).to be_present
    end

    it "returns nil for completed uploads" do
      batch_upload = build(:certification_batch_upload, :completed)

      expect(helper.status_alert_options(batch_upload)).to be_nil
    end
  end
end
