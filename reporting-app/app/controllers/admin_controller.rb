# frozen_string_literal: true

class AdminController < StaffController
  self.authorization_resource = :admin

  def index
    raise NotImplementedError, "Subclasses must implement the index action"
  end
end
