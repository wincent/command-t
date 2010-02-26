module CommandT
  # Reads the current directory recursively for the paths to all regular files.
  # Exists as a separate class to allow for the possibility of plugging in
  # different scanning methods (calling "find", staying within Ruby, using a
  # C extension that uses the FSEvents API etc).
  class Scanner
    def flush
      @paths = nil
    end

    def paths
      @paths ||= `find . -type f 2> /dev/null`.split("\n")
    end
  end
end # module CommandT
