module CommandT
  module Scanner
    # Common methods to be inherited by concrete subclasses.
    class Base
      def flush
        @paths = nil
      end

      def path= str
        if @path != str
          @path = str
          flush
        end
      end
    end # class AbstractScanner
  end # module Scanner
end # module CommandT
