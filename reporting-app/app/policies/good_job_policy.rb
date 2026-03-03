# frozen_string_literal: true

# Policy for GoodJob dashboard access
# Admin-only access for monitoring and managing background jobs
class GoodJobPolicy < AdminPolicy
  def dashboard?
    admin?
  end
end
