module CommandT
  # Reads the current directory recursively for the paths to all regular files.
  module Scanner
    autoload :Find, 'command-t/scanner/find'

    def self.scanner path = nil
      Find.new path
    end
  end # module Scanner
end # module CommandT
