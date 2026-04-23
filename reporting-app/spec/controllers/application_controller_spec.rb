# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  controller do
    skip_after_action :verify_policy_scoped
    def index
      render plain: :foo
    end
  end

  describe "View paths" do
    it "first resolves to app/views/overrides" do
      first_view_path = controller.view_paths.first
      expect(first_view_path.path).to eq File.expand_path("app/views/overrides")
    end

    describe "Demo theme" do
      let(:view_demo_theme) { File.expand_path("app/views/demo_theme") }
      let(:controller_paths) { controller.view_paths.map(&:path) }

      before do
        controller do
          def index; end
        end
      end

      it "is not in view path by default" do
        with_demo_theme_enabled do
          expect(controller_paths).not_to include(view_demo_theme)
        end
      end

      it "is in view path if enabled" do
        with_demo_theme_enabled do
          get :index, params: { theme: "nava_pbc" }
          first_view_path = controller.view_paths.first
          expect(first_view_path.path).to eq view_demo_theme
        end
      end

      it "is not in view if feature flag not set" do
        get :index, params: { theme: "nava_pbc" }
        expect(controller_paths).not_to include(view_demo_theme)
      end

      it "continues in view path after enabled" do
        with_demo_theme_enabled do
          get :index, params: { theme: "nava_pbc" }

          get :index
          first_view_path = controller.view_paths.first
          expect(first_view_path.path).to eq view_demo_theme
        end
      end

      it "is not in view path after theme reset" do
        with_demo_theme_enabled do
          get :index, params: { theme: "nava_pbc" }

          get :index, params: { theme: "reset" }
          expect(controller_paths).not_to include(view_demo_theme)
        end
      end

      it "continues not to be in view path after theme reset" do
        with_demo_theme_enabled do
          get :index, params: { theme: "nava_pbc" }
          get :index, params: { theme: "reset" }

          request.cookies.update(response.cookies)
          get :index
          expect(controller_paths).not_to include(view_demo_theme)
        end
      end
    end
  end
end
