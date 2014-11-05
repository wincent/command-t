# Copyright 2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  module SCMUtilities

  private

    def nearest_ancestor(starting_directory, markers)
      path = File.expand_path(starting_directory)
      while !markers.
        map { |dir| File.join(path, dir) }.
        map { |dir| File.exist?(dir) }.
        any?
        next_path = File.expand_path(File.join(path, '..'))
        return nil if next_path == path
        path = next_path
      end
      path
    end
  end # module SCMUtilities
end # module CommandT
