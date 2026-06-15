# frozen_string_literal: true

namespace :dev do
  namespace :member_dashboard do
    desc "List OSCER-337 member dashboard exemption frames for local QA"
    task frames: :environment do
      abort "dev:member_dashboard tasks are only available in development" unless Rails.env.development?

      puts "Member dashboard exemption frames (use with dev:member_dashboard:apply[EMAIL,FRAME]):"
      Dev::MemberDashboardFrameSetup.list_frames
      puts
      puts "Example:"
      puts "  docker compose exec reporting-app bin/rake 'dev:member_dashboard:apply[jake@test.com,exemption_pending_review]'"
    end

    desc "Apply a member dashboard exemption frame for local QA (EMAIL,FRAME)"
    task :apply, [ :email, :frame ] => :environment do |_task, args|
      abort "dev:member_dashboard tasks are only available in development" unless Rails.env.development?

      email = args[:email].presence || ENV.fetch("MEMBER_EMAIL", "jake@test.com")
      frame = args[:frame].presence || ENV.fetch("MEMBER_DASHBOARD_FRAME", "exemption_pending_review")

      Dev::MemberDashboardFrameSetup.apply!(email: email, frame: frame)
    end
  end
end
