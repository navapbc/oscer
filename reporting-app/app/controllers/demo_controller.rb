# frozen_string_literal: true

class DemoController < ActionController::Base
  include DemoAccessGate

  layout "demo"

  def index
  end
end
