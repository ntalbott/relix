module Relix
  module Keyer
    def self.default_for(klass)
      Legacy.new(klass)
    end

    class Legacy
      def initialize(klass)
        @prefix = klass.name
      end

      def values(pk)
        "#{@prefix}:current_values:#{pk}"
      end
    end

    class Standard
      def initialize(klass)
        @prefix = klass.name
      end

      def values(pk)
        "#{@prefix}:values:#{pk}"
      end
    end
  end
end