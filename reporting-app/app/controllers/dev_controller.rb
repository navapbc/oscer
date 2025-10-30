# frozen_string_literal: true

class DevController < ApplicationController
  layout "sidenav"

  before_action :check_env

  # Frontend sandbox for testing purposes during local development
  def sandbox
    skip_authorization
  end

  private

  def check_env
    unless Rails.env.development?
      redirect_to root_path
      nil
    end
  end
end
