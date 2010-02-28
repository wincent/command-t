module CommandT
  # Reads the current directory recursively for the paths to all regular files.
  module Scanner
    autoload :Base, 'command-t/scanner/base'
    autoload :Find, 'command-t/scanner/find'
    autoload :Ruby, 'command-t/scanner/ruby'

    def self.scanner path = nil
      Ruby.new path
    end
  end # module Scanner
end # module CommandT
