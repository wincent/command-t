# SPDX-FileCopyrightText: Copyright 2015-present Greg Hurrell and contributors.
# SPDX-License-Identifier: BSD-2-Clause

module CommandT
  module Metadata
    # This file gets overwritten with actual data during the installation
    # process (when `ruby extconf.rb` is run).
    EXPECTED_RUBY_VERSION = '[unknown]'
    EXPECTED_RUBY_PATCHLEVEL = '[unknown]'
    UNKNOWN = true
  end
end
