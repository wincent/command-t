# Copyright 2010-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class ProgressReporter
    SPINNER = %w[^ > v <]

    def initialize
      @spinner ||= SPINNER.first
    end

    def update(count)
      @spinner = SPINNER[(SPINNER.index(@spinner) + 1) % SPINNER.length]

      ::VIM::command "echon '#{@spinner}  #{count}'"
      ::VIM::command 'redraw'

      # Aim for 5 updates per second.
      now = Time.now.to_f
      if @last_time
        time_diff = now - @last_time
        count_diff = count - @last_count
        next_count = count + ((0.2 / time_diff) * count_diff).to_i
      else
        next_count = count + 100
      end
      @last_time = now
      @last_count = count
      next_count
    end
  end
end
