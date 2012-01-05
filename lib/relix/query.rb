module Relix
  class Query
    def initialize(model)
      @model = model
      @offset = 0
    end

    def [](index_name)
      index = @model.indexes[index_name.to_s]
      raise MissingIndexError.new("No index declared for #{index_name}") unless index
      @clause = Clause.new(@model.redis, index)
    end

    def run
      if @clause
        @clause.lookup
      else
        @model.primary_key_index.lookup
      end
    end

    class Clause
      def initialize(redis, index)
        @redis = redis
        @index = index
        @options = {}
      end

      def eq(value, options={})
        @value = @index.normalize(value)
        @options = options
      end

      def all(options={})
        @all = true
        @options = options
      end

      def lookup
        if @options[:limit] == 0
          []
        elsif @all
          @index.all(@redis, @options)
        else
          @index.eq(@redis, @value, @options)
        end
      end
    end
  end

  class MissingIndexError < Relix::Error; end
end