module CommandT
  module Scanner
    # Common methods to be inhertied by concrete subclasses.
    class Base
      def flush
        @paths = nil
      end

      def path= str
        @path = str
        flush
      end
    end # class AbstractScanner
  end # module Scanner
end # module CommandT
