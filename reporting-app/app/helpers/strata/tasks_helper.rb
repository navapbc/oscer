# frozen_string_literal: true

module Strata
  module TasksHelper
    def task_filter_params
      params.permit(:filter_date, :filter_type, :filter_status)
    end

    def task_tabs
      [
        {
          name: t("strata.tasks.index.tabs.assigned"),
          path: url_for(task_filter_params.merge(filter_status: nil)),
          active: params[:filter_status].nil? || params[:filter_status] == "pending"
        },
        {
          name: t("strata.tasks.index.tabs.on_hold"),
          path: url_for(task_filter_params.merge(filter_status: "on_hold")),
          active: params[:filter_status] == "on_hold"
        },
        {
          name: t("strata.tasks.index.tabs.completed"),
          path: url_for(task_filter_params.merge(filter_status: "completed")),
          active: params[:filter_status] == "completed"
        }
      ]
    end
  end
end
