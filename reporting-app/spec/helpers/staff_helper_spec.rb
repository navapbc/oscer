# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StaffHelper, type: :helper do
  describe "time_to_close_days" do
    it "returns no data when no data" do
      result = helper.time_to_close_days({})
      expect(result).to eq 'no data'
    end

    it "returns single form when 1 day" do
      result = helper.time_to_close_days({ time_to_close_seconds: 1.day })
      expect(result).to eq '1 day'
    end

    it "returns plural form when not 1 day" do
      result = helper.time_to_close_days({ time_to_close_seconds: 2.days })
      expect(result).to eq '2 days'
    end
  end
end
