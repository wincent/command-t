module CommandT
  module Scanner
    class Ruby
      class DepthLimitExceeded < ::RuntimeError; end
      class FileLimitExceeded < ::RuntimeError; end

      def initialize path = Dir.pwd, options = {}
        @path       = path
        @max_depth  = options[:max_depth] || 15
        @max_files  = options[:max_files] || 10_000
        @exclude    = options[:excludes] || /\A(\.git)\z/
      end

      def flush
        @paths = nil
      end

      def paths
        return @paths unless @paths.nil?
        begin
          @paths = []
          @depth = 0
          @files = 0
          @prefix_len = @path.length
          add_paths_for_directory @path, @paths
        rescue FileLimitExceeded, DepthLimitExceeded
        end
        @paths
      end

      private

      def add_paths_for_directory dir, accumulator
        Dir.foreach(dir) do |entry|
          next if ['.', '..'].include?(entry)
          path = File.join(dir, entry)
          unless entry.match(@exclude)
            if File.file?(path)
              @files += 1
              raise FileLimitExceeded if @files > @max_files
              accumulator << path[@prefix_len + 1..-1]
            elsif File.directory?(path)
              @depth += 1
              raise DepthLimitExceeded if @depth > @max_depth
              add_paths_for_directory path, accumulator
            end
          end
        end
      end
    end # class Ruby
  end # module Scanner
end # module CommandT
