# Copyright 2010-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Stub
    @@expected_version = Metadata::EXPECTED_RUBY_VERSION
    @@expected_patchlevel = Metadata::EXPECTED_RUBY_PATCHLEVEL
    @@patch_level = defined?(RUBY_PATCHLEVEL) ? RUBY_PATCHLEVEL : '[unknown]'
    @@load_error = ['command-t.vim could not load the C extension',
                    'Please see INSTALLATION and TROUBLE-SHOOTING in the help',
                    "Vim Ruby version: #{RUBY_VERSION}-p#{@@patch_level}",
                    "Expected version: #{@@expected_version}-p#{@@expected_patchlevel}",
                    'For more information type:    :help command-t']

    [
      :flush,
      :show_buffer_finder,
      :show_file_finder,
      :show_jump_finder,
      :show_mru_finder,
      :show_tag_finder
    ].each do |method|
      define_method(method) { warn *@@load_error }
    end

  private

    def warn(*msg)
      ::VIM::command 'echohl WarningMsg'
      msg.each { |m| ::VIM::command "echo '#{m}'" }
      ::VIM::command 'echohl none'
    end
  end # class Stub
end # module CommandT
