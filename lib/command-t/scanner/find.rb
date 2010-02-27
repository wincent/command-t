module CommandT
  module Scanner
    # Simplistic scanner that wraps 'find . -type f'.
    class Find
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
    end # class Find
  end # module Scanner
end # module CommandT
