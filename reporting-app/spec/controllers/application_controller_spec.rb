# frozen_string_literal: true

require 'rails_helper'
require 'fileutils'

RSpec.describe ApplicationController, type: :controller do
  controller do
    skip_after_action :verify_policy_scoped
    def index
      render :test_template, layout: false
    end
  end

  describe "View paths" do
    it "first resolves to app/views/overrides" do
      first_view_path = controller.view_paths.first
      expect(first_view_path.path).to eq File.expand_path("app/views/overrides")
    end

    describe "override template" do
      render_views
      let(:anonymous_dirs) { [ "app/views/anonymous", "app/views/overrides/anonymous" ] }
      let(:base_filepath) { Rails.root.join("#{anonymous_dirs[0]}/test_template.html.erb") }
      let(:base_content) { "base" }
      let(:override_filepath) { Rails.root.join("#{anonymous_dirs[1]}/test_template.html.erb") }
      let(:override_content) { "override" }

      before do
        anonymous_dirs.each { |anonymous_dir| FileUtils.mkdir_p(anonymous_dir) }
        File.write(base_filepath, base_content)
        File.write(override_filepath, override_content)
      end

      after do
        anonymous_dirs.each { |anonymous_dir| FileUtils.rm_rf(anonymous_dir) }
      end

      it "renders override content" do
        get :index
        expect(response.body).to eq override_content
      end
    end
  end
end
