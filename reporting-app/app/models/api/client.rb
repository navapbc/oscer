# frozen_string_literal: true

class Api::Client
  # represents an authenticated API client (state system)
  # Used by Pundit policies

  def state_system?
    true
  end

  def staff?
    false
  end

  def member?
    false
  end
end
