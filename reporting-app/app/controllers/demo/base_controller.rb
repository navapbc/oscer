# frozen_string_literal: true

class Demo::BaseController < ApplicationController
  include DemoAccessGate

  layout "demo"
end
