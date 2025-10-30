# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HomeController do
  render_views

  describe "GET index" do
    it "renders the index template" do
      get :index, params: { locale: "en" }

      expect(response.body).to have_selector("h1", text: /get started/i)
    end
  end
end
