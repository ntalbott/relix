module Relix
  class Index
    def self.kind
      @kind ||= name.gsub(/(?:^.+::|Index$)/, '').gsub(/([a-z])([A-Z])/){"#{$1}_#{$2}"}.downcase
    end

    def self.compact_kind
      @compact_kind ||= kind[0..0]
    end

    class Accessor
      attr_reader :identifier
      def initialize(name)
        @accessor = name.to_s
        if @accessor =~ /^(.+)\?$/
          @identifier = $1
          @interrogative = true
        else
          @identifier = @accessor
        end
      end

      def read(object)
        result = object.send(@accessor)
        result = !!result if @interrogative
        result
      end
    end

    attr_reader :model_name
    def initialize(set, base_name, accessors, options={})
      @set = set
      @base_name = base_name
      @model_name = @set.klass.name
      @accessors = Array(accessors).collect{|a| Accessor.new(a)}
      @attribute_immutable = options[:immutable_attribute]
      @options = options
    end

    def name
      @set.keyer.index(self, @base_name)
    end

    def read(object)
      @accessors.inject({}){|h,e| h[e.identifier] = e.read(object); h}
    end

    def read_normalized(object)
      normalize(read(object))
    end

    def normalize(value)
      value_hash = case value
      when Hash
        value.inject({}){|h, (k,v)| h[k.to_s] = v; h}
      else
        {@accessors.first.identifier => value}
      end
      @accessors.collect do |accessor|
        if value_hash.include?(accessor.identifier)
          value_hash[accessor.identifier].to_s
        else
          raise MissingIndexValueError, "Missing #{accessor.identifier} when looking up by #{name}"
        end
      end.join(":")
    end

    def watch(*values)
      watch_keys(*values) unless attribute_immutable?
    end

    def watch_keys(*values)
      nil
    end

    def filter(r, object, value)
      true
    end

    def query(r, value)
      nil
    end

    def create_query_clause(redis)
      Query::Clause.new(redis, self)
    end

    def attribute_immutable?
      @attribute_immutable
    end

    module Ordering
      def initialize(*args)
        super
        @order = @options[:order]
      end

      def score(object, value)
        if @order
          value = object.send(@order)
        end

        score_for_value(value)
      end

      def score_for_value(value)
        case value
        when Numeric
          value
        when Time
          value.to_f
        else
          if value.respond_to?(:to_i)
            value.to_i
          elsif value.respond_to?(:to_time)
            value.to_time.to_f
          elsif @order
            raise UnorderableValueError.new("Unable to convert #{value} in to a number for ordering.")
          else
            0
          end
        end
      end

      def range_from_options(r, options, value=nil)
        start = (options[:offset] || 0)
        if f = options[:from]
          start = (position(r, f, value) + 1)
        end
        stop = (options[:limit] ? (start + options[:limit] - 1) : -1)
        [start, stop]
      end
    end
  end

  class UnorderableValueError < Relix::Error; end
  class MissingIndexValueError < Relix::Error; end
end
