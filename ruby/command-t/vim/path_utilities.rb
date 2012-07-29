# Copyright 2010-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'command-t/vim'

module CommandT
  module VIM
    module PathUtilities

    private

      def get_string name
        VIM::exists?(name) ? ::VIM::evaluate("#{name}").to_s : nil
      end

      def relative_path_under_working_directory path
        # any path under the working directory will be specified as a relative
        # path to improve the readability of the buffer list etc
        pwd = File.expand_path(VIM::pwd) + '/'
        path.index(pwd) == 0 ? path[pwd.length..-1] : path
      end

      def nearest_scm_directory
        # find nearest parent determined to be an scm root
        # based on marker directories in default_markers or
        # g:command_t_root_markers

        markers = get_string('g:command_t_root_markers')
        default_markers = ['.git', '.hg', '.svn', '.bzr', '_darcs']
        if not (markers and markers.length)
            markers = default_markers
        end

        path = File.expand_path(VIM::current_file_dir)
        while !markers.
            map{|dir| File.join(path, dir)}.
            map{|dir| File.directory?(dir)}.
            any?
          return Dir.pwd if path == "/"
          path = File.expand_path(File.join(path, '..'))
        end
        path
      end

    end # module PathUtilities
  end # module VIM
end # module CommandT
