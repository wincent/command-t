module CommandT
  # Reads the current directory recursively for the paths to all regular files.
  # Exists as a separate class to allow for the possibility of plugging in
  # different scanning methods (calling "find", staying within Ruby, using a
  # C extension that uses the FSEvents API etc).
  class Scanner

    # Optionally accept a specific path to use (principally for testing).
    def initialize path = Dir.pwd
      @path = path
    end

    def flush
      @paths = nil
    end

    def paths
      return @paths unless @paths.nil?
      begin
        pwd = Dir.pwd
        Dir.chdir @path
        @paths = `find . -type f 2> /dev/null`.split("\n")
      ensure
        Dir.chdir pwd
      end
      @paths
    end
  end
end # module CommandT
