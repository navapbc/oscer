# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Member, type: :model do
  describe '.from_certification' do
    let(:member_data) do
      build(:certification_member_data, :with_full_name)
    end
    let(:certification) do
      create(:certification,
        :connected_to_email,
        member_id: "MEMBER123",
        email: "test@example.com",
        member_data: member_data
      )
    end

    it 'creates a Member from a Certification' do
      member = described_class.from_certification(certification)

      expect(member.member_id).to eq("MEMBER123")
      expect(member.email).to eq("test@example.com")
      expect(member.name).to be_a(Strata::Name)
      expect(member.name.full_name).to be_present
      expect(member.name.first).to be_present
      expect(member.name.middle).to be_present
      expect(member.name.last).to be_present
    end
  end

  describe '.find_by_member_id' do
    let(:member_data) { build(:certification_member_data, :with_full_name) }

    before do
      create(:certification,
        :connected_to_email,
        member_id: "MEMBER123",
        email: "test@example.com",
        member_data: member_data
      )
    end

    it 'finds a member by member_id' do
      member = described_class.find_by_member_id("MEMBER123")

      expect(member.member_id).to eq("MEMBER123")
      expect(member.email).to eq("test@example.com")
      expect(member.name).to be_a(Strata::Name)
      expect(member.name.full_name).to be_present
    end
  end

  describe '.search_by_email' do
    let(:member_data_one) { build(:certification_member_data, :with_full_name) }
    let(:member_data_two) { build(:certification_member_data, :with_name_parts) }

    before do
      create(:certification,
        :connected_to_email,
        member_id: "MEMBER1",
        email: "test@example.com",
        member_data: member_data_one
      )

      create(:certification,
        :connected_to_email,
        member_id: "MEMBER2",
        email: "test@example.com",
        member_data: member_data_two
      )
    end

    it 'finds all members with matching email' do
      members = described_class.search_by_email("test@example.com")

      expect(members.length).to eq(2)
      expect(members.map(&:member_id)).to contain_exactly("MEMBER1", "MEMBER2")
      expect(members.all? { |m| m.name.full_name.present? }).to be true
    end
  end
end
