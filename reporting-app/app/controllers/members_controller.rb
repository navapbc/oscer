# frozen_string_literal: true

class MembersController < StaffController
  def index
    redirect_to search_members_path
  end

  def show
    member_id = params[:id]
    @member = Member.find_by_member_id(member_id)
    @certification_cases = certification_service.find_cases_by_member_id(member_id)
  end

  def search
    @members = Member.search_by_email(params[:email])
  end

  private

  def certification_service
    CertificationService.new
  end
end
