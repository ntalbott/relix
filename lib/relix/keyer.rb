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

      def index(index, name)
        case index
        when PrimaryKeyIndex
          "#{index.class.name}:#{@prefix}:primary_key"
        else
          "#{index.class.name}:#{@prefix}:#{name}"
        end
      end

      def component(name, component)
        component = case component
        when 'lookup'
          'hash'
        when 'ordering'
          'zset'
        else
          component
        end

        "#{name}:#{component}"
      end
    end

    class Standard
      def initialize(klass)
        @prefix = klass.name
      end

      def values(pk)
        "#{@prefix}:values:#{pk}"
      end

      def index(index, name)
        "#{@prefix}:#{name}:#{index.class.kind}"
      end

      def component(name, component)
        "#{name}:#{component}"
      end
    end
  end
end