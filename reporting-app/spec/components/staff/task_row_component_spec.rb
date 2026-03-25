# frozen_string_literal: true

require "rails_helper"

RSpec.describe Staff::TaskRowComponent, type: :component do
  let(:certification) { create(:certification, certification_requirements: build(:certification_certification_requirements, region: "Southeast")) }
  let(:certification_case) { create(:certification_case, certification_id: certification.id) }
  let(:task) { create(:review_activity_report_task, case: certification_case) }

  describe ".columns" do
    it "matches the SDK base columns when doc_ai is disabled" do
      with_doc_ai_disabled do
        expect(described_class.columns).to eq(Strata::Tasks::TaskRowComponent.columns)
      end
    end

    it "appends :confidence when doc_ai is enabled" do
      with_doc_ai_enabled do
        expect(described_class.columns).to eq(Strata::Tasks::TaskRowComponent.columns + [ :confidence ])
      end
    end
  end

  describe ".header_translation_for" do
    it "returns the staff confidence label for the confidence column" do
      expect(described_class.header_translation_for(:confidence)).to eq(I18n.t("staff.tasks.index.confidence"))
    end
  end

  describe "#row_classes" do
    it "returns nil when doc_ai is disabled" do
      with_doc_ai_disabled do
        component = described_class.new(task: task, confidence_by_case: { task.case_id => 0.55 })
        expect(component.row_classes).to be_nil
      end
    end

    it "returns bg-error-lighter when doc_ai is enabled and case confidence is below threshold" do
      with_doc_ai_enabled do
        component = described_class.new(task: task, confidence_by_case: { task.case_id => 0.55 })
        expect(component.row_classes).to eq("bg-error-lighter")
      end
    end

    it "returns nil when doc_ai is enabled and case confidence is at or above threshold" do
      with_doc_ai_enabled do
        component = described_class.new(task: task, confidence_by_case: { task.case_id => 0.85 })
        expect(component.row_classes).to be_nil
      end
    end
  end

  describe "rendering" do
    # render_inline has no controller/request, so Strata::Tasks::TaskRowComponent#type cannot
    # resolve url_for(action: :show, id: ...). Stub the path tasks#show would generate.
    def render_staff_task_row(task:, confidence_by_case:)
      component = described_class.new(task: task, confidence_by_case: confidence_by_case)
      allow(component).to receive(:helpers).and_wrap_original do |method, *args|
        helper = method.call(*args)
        allow(helper).to receive(:url_for).and_return("/staff/tasks/#{task.id}")
        helper
      end
      render_inline(component)
    end

    it "renders the confidence percentage when doc_ai is enabled and data exists" do
      with_doc_ai_enabled do
        render_staff_task_row(task: task, confidence_by_case: { task.case_id => 0.85 })
        expect(page.text).to include("85%")
      end
    end

    it "renders an em dash in the confidence cell when there is no confidence data" do
      with_doc_ai_enabled do
        render_staff_task_row(task: task, confidence_by_case: {})
        confidence_cells = page.all("td.text-right.text-no-wrap", visible: :all)
        expect(confidence_cells.map { |td| td.text.strip }).to include("—")
      end
    end
  end
end
