module CommandT
  class Scanner
    class FileScanner
      class CompositeFileScanner
        def initialize(scanners)
          @scanners = scanners
        end

        def paths
          try_paths
        end

        def path=(path)
          @scanners.each do |scanner|
            scanner.path = path
          end
        end

        def flush
          @scanners.each do |scanner|
            scanner.flush
          end
        end

      private

        def try_paths(enum = @scanners.to_enum)
          enum.next.paths
        rescue RuntimeError, Errno::ENOENT
          try_paths(enum)
        rescue StopIteration
          raise RuntimeError, 'No scanners left'
        end
      end
    end
  end
end
