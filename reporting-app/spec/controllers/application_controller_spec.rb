# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationController do
  describe "View paths" do
    it "app/views/overrides resolves first" do
      first_view_path = controller.view_paths.first
      expect(first_view_path.path).to eq File.expand_path("app/views/overrides")
    end
  end
end
