# frozen_string_literal: true

module DateUtils
  module_function

  def month_difference(start_date, end_date)
    raise TypeError, "expected a Date instance for start_date" unless start_date.is_a?(Date)
    raise TypeError, "expected a Date instance for end_date" unless end_date.is_a?(Date)

    (end_date.month - start_date.month) + 12 * (end_date.year - start_date.year)
  end
end
