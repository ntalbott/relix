module Relix
  def self.default_keyer(keyer=nil, options={})
    if keyer
      @default_keyer ||= [keyer, options]
    else
      @default_keyer
    end
  end

  module Keyer
    def self.default_for(klass)
      dk = Relix.default_keyer
      dk.first.new(klass, dk.last)
    end

    class Legacy
      def initialize(klass, options)
        @prefix = klass.name
      end

      def values(pk, klass)
        "#{klass.name}:current_values:#{pk}"
      end

      def index(index, name)
        case index
        when PrimaryKeyIndex
          "#{index.class.name}:#{index.model_name}:primary_key"
        else
          "#{index.class.name}:#{index.model_name}:#{name}"
        end
      end

      def component(name, component)
        if name =~ /^Relix::UniqueIndex:/
          component = case component
          when 'lookup'
            'hash'
          when 'ordering'
            'zset'
          else
            component
          end
        end

        "#{name}:#{component}"
      end
    end

    class Standard
      def initialize(klass, options)
        @prefix = klass.name
      end

      def values(pk, klass)
        "#{@prefix}:values:#{pk}"
      end

      def index(index, name)
        "#{index.model_name}:#{name}:#{index.class.kind}"
      end

      def component(name, component)
        "#{name}:#{component}"
      end
    end

    class Compact < Standard
      def initialize(klass, options)
        @prefix = if(abbrev = options[:abbrev])
          (abbrev.respond_to?(:call) ? abbrev.call(klass.name) : abbrev)
        else
          klass.name
        end
      end

      def values(pk, klass)
        "#{@prefix}:v:#{pk}"
      end

      def index(index, name)
        "#{@prefix}:#{name}:#{index.class.compact_kind}"
      end
    end
  end

  default_keyer(Keyer::Standard)
end