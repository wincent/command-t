# Copyright 2011-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Scanner
    class HelpScanner < Scanner
      def paths
        @cached_tags ||= paths!
      end

      def flush
        @cached_tags = nil
      end

    private

      def paths!
        # Vim doesn't provide an easy way to get a list of all help tags.
        # `tagfiles()` only shows the tagfiles for the current buffer, so you
        # need to already be in a buffer of `'buftype'` `help` for that to work.
        # Likewise, `taglist()` only shows tags that apply to the current file
        # type, and `:tag` has the same restriction.
        #
        # So, we look for a "doc/tags" file at every location in the
        # `'runtimepath'` and try to manually parse it.
        paths = []

        ::VIM::evaluate('&runtimepath').to_s.split(',').each do |path|
          tags = path + '/doc/tags'
          if File.readable?(tags)
            File.readlines(tags).each do |tag|
              paths << tag.split.first if tag.split.first
            end
          end
        end

        paths
      end
    end
  end
end
