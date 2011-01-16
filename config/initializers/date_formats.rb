Time::DATE_FORMATS[:line_grapher] = lambda { |date| date.strftime("%Y%m%dT%H:%M:%S") }
Date::DATE_FORMATS[:line_grapher] = lambda { |date| date.strftime("%Y%m%dT%H:%M:%S") }
Time::DATE_FORMATS[:line_graph] = lambda { |date| date.strftime("%m/%d") }
Date::DATE_FORMATS[:line_graph] = lambda { |date| date.strftime("%m/%d") }
