# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CertificationService do
  let(:service) { described_class.new }
  let(:open_case) { create(:certification_case) }
  let(:closed_case) { create(:certification_case, :with_closed_status) }

  before do
    open_case
    closed_case
  end

  describe '#fetch_open_cases' do
    it 'returns only open cases with their certifications hydrated' do
      result = service.fetch_open_cases

      expect(result).to contain_exactly(open_case)
    end

    it 'does not return closed cases' do
      result = service.fetch_open_cases

      expect(result).not_to include(closed_case)
    end
  end

  describe '#fetch_closed_cases' do
    it 'returns only closed cases with their certifications hydrated' do
      result = service.fetch_closed_cases

      expect(result).to contain_exactly(closed_case)
    end

    it 'does not return open cases' do
      result = service.fetch_closed_cases

      expect(result).not_to include(open_case)
    end
  end
end
