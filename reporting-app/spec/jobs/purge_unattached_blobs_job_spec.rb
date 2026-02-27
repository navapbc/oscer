# frozen_string_literal: true

require "rails_helper"

RSpec.describe PurgeUnattachedBlobsJob, type: :job do
  include ActiveJob::TestHelper

  describe "#perform" do
    context "when there are unattached blobs older than 24 hours" do
      it "purges them" do
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new("old orphaned file"),
          filename: "old_orphan.csv",
          content_type: "text/csv"
        )
        blob.update_column(:created_at, 25.hours.ago)

        expect { described_class.perform_now }.to change(ActiveStorage::Blob, :count).by(-1)
      end
    end

    context "when there are unattached blobs newer than 24 hours" do
      it "does not purge them" do
        ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new("recent orphaned file"),
          filename: "recent_orphan.csv",
          content_type: "text/csv"
        )

        expect { described_class.perform_now }.not_to change(ActiveStorage::Blob, :count)
      end
    end

    context "when there are attached blobs regardless of age" do
      it "does not purge them" do
        batch_upload = create(:certification_batch_upload)
        batch_upload.file.blob.update_column(:created_at, 48.hours.ago)

        expect { described_class.perform_now }.not_to change(ActiveStorage::Blob, :count)
      end
    end

    context "when there are no matching blobs" do
      it "handles gracefully without errors" do
        expect { described_class.perform_now }.not_to raise_error
      end
    end

    context "when purge raises an error on one blob" do
      it "continues processing remaining blobs" do
        blob1 = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new("blob one"),
          filename: "blob1.csv",
          content_type: "text/csv"
        )
        blob1.update_column(:created_at, 25.hours.ago)

        blob2 = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new("blob two"),
          filename: "blob2.csv",
          content_type: "text/csv"
        )
        blob2.update_column(:created_at, 25.hours.ago)

        allow(blob1).to receive(:purge).and_raise(StandardError, "S3 unavailable")
        allow(blob2).to receive(:purge)

        relation = instance_double(ActiveRecord::Relation)
        allow(ActiveStorage::Blob).to receive(:unattached).and_return(relation)
        allow(relation).to receive_messages(where: relation, includes: relation)
        allow(relation).to receive(:find_each).and_yield(blob1).and_yield(blob2)

        expect { described_class.perform_now }.not_to raise_error
        expect(blob2).to have_received(:purge)
      end
    end

    it "logs the purge summary" do
      allow(Rails.logger).to receive(:info)

      described_class.perform_now

      expect(Rails.logger).to have_received(:info).with("PurgeUnattachedBlobsJob: purged 0 blob(s), 0 failure(s)")
    end
  end
end
