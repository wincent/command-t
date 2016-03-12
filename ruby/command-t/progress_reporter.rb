# Copyright 2010-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  # Simple class for displaying scan progress to the user.
  #
  # The active scanner calls the `#update` method with a `count` to inform it of
  # progress, the reporter updates the UI and then returns a suggested count at
  # which to invoke `#update` again in the future (the suggested count is based
  # on a heuristic that seeks to update the UI about 5 times per second).
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
