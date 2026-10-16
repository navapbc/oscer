# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DeclaredEmergency, type: :model do
  let(:origin_raw) do
    JSON.parse(%Q({
        "declarationDate": "2026-08-18T00:00:00.000Z",
        "declarationRequestDate": "2026-08-17T00:00:00.000Z",
        "declarationRequestNumber": "26140",
        "declarationTitle": "MUKLUK FIRE",
        "declarationType": "FM",
        "designatedArea": "Southeast Fairbanks (Census Area)",
        "designatedIncidentTypes": "R",
        "disasterCloseoutDate": null,
        "disasterNumber": 5672,
        "femaDeclarationString": "FM-5672-AK",
        "fipsCountyCode": "240",
        "fipsStateCode": "02",
        "fyDeclared": 2026,
        "hash": "608a749843b5ff3e0033264b77220e1f58aac816",
        "hmProgramDeclared": false,
        "iaProgramDeclared": false,
        "id": "5f3cd139-146c-4b95-be63-f0e4f19e02af",
        "ihProgramDeclared": false,
        "incidentBeginDate": "2026-08-17T00:00:00.000Z",
        "incidentEndDate": "2026-08-20T20:50:08.994Z",
        "incidentId": "2026081802",
        "incidentType": "Fire",
        "lastIAFilingDate": null,
        "lastRefresh": "2026-08-20T20:50:08.994Z",
        "paProgramDeclared": true,
        "placeCode": "99240",
        "region": 10,
        "state": "AK",
        "tribalRequest": false
      }))
  end

  context "when create" do
    it "validates fips" do
      declared_emergency = build(:declared_emergency, fips_code: "218")
      expect(declared_emergency).to be_valid

      declared_emergency.fips_code = "11a"
      expect(declared_emergency).not_to be_valid

      declared_emergency.fips_code = "11"
      expect(declared_emergency).not_to be_valid

      declared_emergency.fips_code = "2222"
      expect(declared_emergency).not_to be_valid
    end

    it "does not create with same origin_id with undeleted still there" do
      origin_id = "some-guid"
      create(:declared_emergency, origin_id:)
      expect do
        create(:declared_emergency, origin_id:)
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "creates with same origin_id if existing deleted" do
      origin_id = "some-guid"
      create(:declared_emergency, origin_id:, deleted_on: Date.current)
      expect(create(:declared_emergency, origin_id:)).to be_truthy
    end

    it "allows multiple records with no origin_id" do
      create(:declared_emergency, origin_id: nil, origin_raw: { a: 1 })
      expect(create(:declared_emergency, origin_id: nil, origin_raw: { b: 2 })).to be_truthy
    end

    it "allows multiple records with no origin_hash" do
      create(:declared_emergency, origin_raw: nil)
      expect(create(:declared_emergency, origin_raw: nil)).to be_truthy
    end

    it "does not supersede other records when origin_id is nil" do
      existing = create(:declared_emergency, origin_id: nil, origin_raw: { a: 1 })

      create(:declared_emergency, origin_id: nil, origin_raw: { b: 2 })

      expect(existing.reload.deleted_on).to be_nil
    end

    describe "date validation" do
      it "validates period_start presence" do
        declared_emergency = build(:declared_emergency, period_start: nil)
        expect(declared_emergency).not_to be_valid
        expect(declared_emergency.errors[:period_start]).to include("can't be blank")
      end

      it "reports an unparsable period_start as a date error, not a blank" do
        declared_emergency = build(:declared_emergency, period_start: "not-a-date")
        expect(declared_emergency).not_to be_valid
        expect(declared_emergency.errors[:period_start]).to eq [ "is not a valid date" ]
      end

      it "validates period_end date format" do
        declared_emergency = build(:declared_emergency, period_end: "not-a-date")
        expect(declared_emergency).not_to be_valid
        expect(declared_emergency.errors[:period_end]).to eq [ "is not a valid date" ]
      end

      it "allows a nil period_end" do
        expect(build(:declared_emergency, period_end: nil)).to be_valid
      end

      it "rejects an unparsable incidentBeginDate from a stanza" do
        expect do
          described_class.create_from_stanza(origin_raw.merge({ "incidentBeginDate" => "garbage" }))
        end.not_to change(described_class, :count)
      end

      it "rejects an unparsable incidentEndDate from a stanza" do
        expect do
          described_class.create_from_stanza(origin_raw.merge({ "incidentEndDate" => "garbage" }))
        end.not_to change(described_class, :count)
      end
    end

    context "with origin_hash" do
      it "uses the hash in origin if set" do
        declared_emergency = build(:declared_emergency, origin_raw: { hash: "foo" }.with_indifferent_access)

        expect(declared_emergency.origin_hash).to be_nil

        declared_emergency.validate
        expect(declared_emergency.origin_hash).to eq "foo"
      end

      it "automatically sets it" do
        declared_emergency = build(:declared_emergency)
        expect(declared_emergency.origin_raw).not_to be_nil
        expect(declared_emergency.origin_hash).to be_nil

        declared_emergency.validate
        expect(declared_emergency.origin_hash).not_to be_nil
      end

      it "doesn't set if origin_raw nil" do
        declared_emergency = build(:declared_emergency, origin_raw: nil)
        expect(declared_emergency.origin_raw).to be_nil
        expect(declared_emergency.origin_hash).to be_nil

        declared_emergency.validate
        expect(declared_emergency.origin_hash).to be_nil
      end

      it "doesn't set if origin_raw empty" do
        declared_emergency = build(:declared_emergency, origin_raw: "")
        expect(declared_emergency.origin_raw).to eq ""
        expect(declared_emergency.origin_hash).to be_nil

        declared_emergency.validate
        expect(declared_emergency.origin_hash).to be_nil
      end

      it "doesn't set if origin_raw is not a hash" do
        declared_emergency = build(:declared_emergency, origin_raw: 42)

        expect { declared_emergency.validate }.not_to raise_error
        expect(declared_emergency.origin_hash).to be_nil
      end

      it "produces same output even if not declared in same order" do
        emergency_a = build(:declared_emergency, origin_raw: { biz: :baz, bom: :bing })
        emergency_b = build(:declared_emergency, origin_raw: { bom: :bing, biz: :baz })
        emergency_a.validate
        emergency_b.validate
        expect(emergency_a.origin_hash).to eq emergency_b.origin_hash
      end

      it "does not create with same origin_hash with undeleted still there" do
        origin_raw = { biz: :baz, bom: :bing }
        create(:declared_emergency, origin_raw:)

        expect do
          create(:declared_emergency, origin_raw:)
        end.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "creates with same origin_hash if existing deleted" do
        origin_raw = { biz: :baz, bom: :bing }
        create(:declared_emergency, origin_raw:, deleted_on: Date.current)
        expect(create(:declared_emergency, origin_raw:)).to be_truthy
      end
    end
  end

  describe "default scope" do
    it "excludes soft deleted records" do
      declared_emergency = create(:declared_emergency)
      declared_emergency.soft_delete

      expect(described_class.count).to eq 0
      expect(described_class.unscoped.count).to eq 1
    end
  end

  describe "read only" do
    it "is read only after persisted" do
      declared_emergency = build(:declared_emergency)
      expect(declared_emergency).not_to be_readonly
      declared_emergency.save
      expect(declared_emergency).to be_readonly
    end

    it "errors on delete" do
      declared_emergency = create(:declared_emergency)
      expect do
        declared_emergency.destroy!
      end.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "errors on update" do
      declared_emergency = create(:declared_emergency)
      expect do
        declared_emergency.update(declaration_title: 'Foo')
      end.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "errors on save after persist" do
      declared_emergency = create(:declared_emergency)
      expect do
        declared_emergency.declaration_title = 'Foo'
        declared_emergency.save!
      end.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "can still mark reported" do
      declared_emergency = create(:declared_emergency)
      expect(declared_emergency.reported_to_cms_on).to be_nil
      today = Date.current
      declared_emergency.mark_reported(today)
      declared_emergency.reload
      expect(declared_emergency.reported_to_cms_on).to eq today
    end

    it "cannot be updated after mark reported" do
      declared_emergency = create(:declared_emergency)
      declared_emergency.mark_reported(Date.current)
      expect do
        declared_emergency.update_attribute(:designated_area, "New Designated Area")
      end.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "stays read only when the write raises" do
      declared_emergency = create(:declared_emergency)
      allow(declared_emergency).to receive(:update_attribute).and_raise(ActiveRecord::StatementInvalid)

      expect { declared_emergency.soft_delete }.to raise_error(ActiveRecord::StatementInvalid)
      expect(declared_emergency).to be_readonly
    end

    it "soft deletes" do
      declared_emergency = create(:declared_emergency)
      expect(declared_emergency.deleted_on).to be_nil

      declared_emergency.soft_delete
      declared_emergency.reload
      expect(declared_emergency.deleted_on).to eq Date.current
    end

    it "cannot be updated after soft delete" do
      declared_emergency = create(:declared_emergency)
      declared_emergency.soft_delete
      expect do
        declared_emergency.update_attribute(:designated_area, "New Designated Area")
      end.to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end

  describe "create from json" do
    it "creates a record" do
      expect do
        described_class.create_from_stanza(origin_raw)
      end.to change(described_class, :count).by(1)
    end

    it "fills in all the details" do
      declared_emergency = described_class.create_from_stanza(origin_raw)
      expect(declared_emergency).to be_valid
      expect(declared_emergency).to be_readonly
      expect(declared_emergency.fips_code).to eq "240"
      expect(declared_emergency.designated_area).to eq "Southeast Fairbanks (Census Area)"
      expect(declared_emergency.declaration_title).to eq "MUKLUK FIRE"
      expect(declared_emergency.reported_to_cms_on).to be_falsey
      expect(declared_emergency.period_start).to eq Date.new(2026, 8, 1)
      expect(declared_emergency.period_end).to eq Date.new(2026, 8, 31)
      expect(declared_emergency.origin_id).to eq "5f3cd139-146c-4b95-be63-f0e4f19e02af"
      expect(declared_emergency.origin_hash).to eq "608a749843b5ff3e0033264b77220e1f58aac816"
      expect(declared_emergency.origin_raw).to eq origin_raw
    end

    it "handles nil end date" do
      declared_emergency = described_class.create_from_stanza(origin_raw.except("incidentEndDate"))
      expect(declared_emergency.period_end).to be_nil
    end

    context "when already exists (id matches)" do
      it "does nothing if hash matches" do
        described_class.create_from_stanza(origin_raw)

        expect do
          described_class.create_from_stanza(origin_raw)
        end.not_to change(described_class, :count)
      end

      it "soft deletes old and creates new if not hash matches" do
        old_disaster =  described_class.create_from_stanza(origin_raw.merge({ "hash" => "foo" }))

        expect do
          described_class.create_from_stanza(origin_raw)
        end.to change(described_class.unscoped, :count).by(1)
        expect(described_class.count).to eq 1

        old_disaster.reload
        expect(old_disaster.deleted_on).to eq Date.current
      end

      it "does not soft delete if error on new" do
        old_disaster = described_class.create_from_stanza(origin_raw.merge({ "hash" => "foo" }))

        expect do
          described_class.create_from_stanza(origin_raw.except("incidentBeginDate"))
        end.not_to change(described_class, :count)

        old_disaster.reload
        expect(old_disaster.deleted_on).to be_nil
      end

      it "re-imports an identical stanza once the existing record is soft deleted" do
        described_class.create_from_stanza(origin_raw).soft_delete

        expect do
          described_class.create_from_stanza(origin_raw)
        end.to change(described_class, :count).by(1)

        expect(described_class.where(deleted_on: nil).count).to eq 1
      end

      it "still imports a hashless stanza when a nil-hash record exists" do
        create(:declared_emergency, origin_raw: nil)

        expect do
          described_class.create_from_stanza(origin_raw.except("hash"))
        end.to change(described_class, :count).by(1)
      end

      it "maintains reported_at" do
        reported_date = 3.months.ago.to_date
        old_disaster = described_class.create_from_stanza(origin_raw.merge({ "hash" => "foo" }))
        old_disaster.mark_reported(reported_date)

        new_disaster = described_class.create_from_stanza(origin_raw)
        expect(new_disaster.reported_to_cms_on).to eq reported_date
      end
    end
  end

  describe "extend end date" do
    it "creates new record" do
      old_disaster = described_class.create_from_stanza(origin_raw)
      new_date = 2.months.from_now.to_date

      expect do
        described_class.extend_end_date(old_disaster, new_date)
      end.to change(described_class.unscoped, :count).by(1)
      expect(described_class.count).to eq 1

      old_disaster.reload
      expect(old_disaster.deleted_on).to eq Date.current
    end

    it "does nothing when the record is already soft deleted" do
      old_disaster = described_class.create_from_stanza(origin_raw)
      old_disaster.soft_delete

      expect do
        described_class.extend_end_date(old_disaster.reload, 2.months.from_now.to_date)
      end.not_to change(described_class, :count)
    end

    it "does not soft delete if new record invalid" do
      old_disaster = described_class.create_from_stanza(origin_raw)
      new_date = 2.months.from_now.to_date

      old_disaster.period_start = nil
      expect do
        described_class.extend_end_date(old_disaster, new_date)
      end.not_to change(described_class, :count)

      old_disaster.reload
      expect(old_disaster.deleted_on).to be_nil
    end
  end
end
