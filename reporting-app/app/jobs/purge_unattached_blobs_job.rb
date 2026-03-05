# frozen_string_literal: true

class PurgeUnattachedBlobsJob < ApplicationJob
  def perform
    purged = 0
    failed = 0

    ActiveStorage::Blob.unattached
      .where("active_storage_blobs.created_at < ?", 24.hours.ago)
      .includes(:variant_records)
      .find_each do |blob|
        blob.purge
        purged += 1
      rescue StandardError => e
        failed += 1
        Rails.logger.warn("PurgeUnattachedBlobsJob: failed to purge blob #{blob.id}: #{e.message}")
      end

    Rails.logger.info("PurgeUnattachedBlobsJob: purged #{purged} blob(s), #{failed} failure(s)")
  end
end
