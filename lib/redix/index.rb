module Redix
  class Index
    def initialize(name, accessor, options={})
      @name = "#{self.class.name}:#{name}"
      @accessor = [accessor].flatten.collect{|a| a.to_s}
      @options = options
    end

    def read(object)
      @accessor.inject({}){|h,e| h[e] = object.send(e); h}
    end

    def read_normalized(object)
      normalize(read(object))
    end

    def normalize(value)
      value_hash = case value
      when Hash
        value.inject({}){|h, (k,v)| h[k.to_s] = v; h}
      else
        {@accessor.first => value}
      end
      @accessor.collect do |k|
        if value_hash.include?(k)
          value_hash[k].to_s
        else
          raise MissingIndexValueError, "Missing #{k} when looking up by #{@name}"
        end
      end.join(":")
    end

    def watch
      nil
    end

    def filter(r, object, value)
      true
    end

    def query(r, value)
      nil
    end

    def key_for(value)
      "#{@name}:#{value}"
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

      def range_from_options(options, value=nil)
        start = (options[:offset] || 0)
        if f = options[:from]
          start = (position(f, value) + 1)
        end
        stop = (options[:limit] ? (start + options[:limit] - 1) : -1)
        [start, stop]
      end
    end
  end

  class UnorderableValueError < StandardError; end
  class MissingIndexValueError < StandardError; end
end