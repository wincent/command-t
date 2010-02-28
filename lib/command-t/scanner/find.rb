module CommandT
  module Scanner
    # Simplistic scanner that wraps 'find . -type f'.
    class Find < Base
      def initialize path = Dir.pwd, options = {}
        @path = path
        @max_depth = 15
        @max_depth = options[:max_depth].to_i unless options[:max_depth].nil?
      end

      def paths
        return @paths unless @paths.nil?
        begin
          pwd = Dir.pwd
          Dir.chdir @path
          @paths = `find . -type f -maxdepth #{@max_depth} 2> /dev/null`.
            split("\n").map { |path| path[2..-1] }
        ensure
          Dir.chdir pwd
        end
        @paths
      end
    end # class Find
  end # module Scanner
end # module CommandT
