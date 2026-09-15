# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CertificationService do
  let(:service) { described_class.new }
  let(:closed_case) { create(:certification_case, :with_closed_status) }

  before do
    closed_case
  end

  describe '#fetch_open_actionable_cases' do
    let(:actionable_case) { create(:certification_case, :actionable) }
    let(:non_actionable_case) { create(:certification_case) }

    before do
      actionable_case
      non_actionable_case
    end

    it 'returns only open actionable cases' do
      result = service.fetch_open_actionable_cases

      expect(result).to contain_exactly(actionable_case)
    end

    it 'does not return closed cases' do
      result = service.fetch_open_actionable_cases

      expect(result).not_to include(closed_case)
    end

    it 'does not return non-actionable cases' do
      result = service.fetch_open_actionable_cases

      expect(result).not_to include(non_actionable_case)
    end

    it 'hydrates cases with their certifications' do
      result = service.fetch_open_actionable_cases.first

      expect(result.certification).to be_present
    end
  end

  describe '#fetch_closed_cases' do
    let(:open_case) { create(:certification_case) }

    before do
      open_case
    end

    it 'returns only closed cases with their certifications hydrated' do
      result = service.fetch_closed_cases

      expect(result).to contain_exactly(closed_case)
    end

    it 'does not return open cases' do
      result = service.fetch_closed_cases

      expect(result).not_to include(open_case)
    end
  end

  describe '#find_cases_by_member_id' do
    let(:member_id) { 'MEMBER-ORDER-1' }
    let(:oldest_case) { build_case(created_at: Time.zone.local(2026, 1, 5, 9, 0, 0)) }
    let(:middle_case) { build_case(created_at: Time.zone.local(2026, 2, 1, 9, 0, 0)) }
    let(:newest_case) { build_case(created_at: Time.zone.local(2026, 3, 10, 12, 0, 0)) }
    let(:expected_order) { [ newest_case.id, middle_case.id, oldest_case.id ] }

    def build_case(created_at:)
      cert = create(:certification, member_id: member_id)
      CertificationCase.find_by!(certification_id: cert.id).tap do |kase|
        kase.update_column(:created_at, created_at)
      end
    end

    before do
      middle_case
      newest_case
      oldest_case
    end

    it 'returns the cases newest first' do
      result = service.find_cases_by_member_id(member_id)

      expect(result.map(&:id)).to eq(expected_order)
    end

    it 'hydrates each case with its certification' do
      result = service.find_cases_by_member_id(member_id)

      expect(result.map { |kase| kase.certification.member_id }).to all(eq(member_id))
    end
  end
end
