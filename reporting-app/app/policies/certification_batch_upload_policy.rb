# frozen_string_literal: true

class CertificationBatchUploadPolicy < AdminPolicy
  def process_batch?
    update?
  end

  def results?
    show?
  end
end
