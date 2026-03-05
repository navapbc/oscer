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
end
