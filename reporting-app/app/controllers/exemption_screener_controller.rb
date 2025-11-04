# frozen_string_literal: true

class ExemptionScreenerController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def index
  end
end
