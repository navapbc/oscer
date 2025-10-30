# frozen_string_literal: true

module PunditSpecViewHelper
  def stub_pundit_for(obj, *perms)
    without_partial_double_verification do
      allow(view).to receive(:policy).with(obj).and_return(
        instance_double(Pundit::PolicyFinder.new(obj).policy!, *perms)
      )
    end
  end
end
