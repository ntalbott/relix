module Relix
  class OrderedIndex < Index
    include Ordering

    def sorted_set_name
      @set.keyer.component(name, 'ordered')
    end

    def watch
      sorted_set_name
    end

    def index(r, pk, object, value, old_value)
      r.zadd(sorted_set_name, score(object, value), pk)
    end

    def deindex(r, pk, object, old_value)
      r.zrem(sorted_set_name, pk)
    end

    def extend_query_clause(query_clause)
      query_clause.extend QueryClauseMethods
    end

    module QueryClauseMethods
      def self.extended(object)
        object.instance_eval do
          @lt, @gt, @limit, @offset, @order = '+inf', '-inf', nil, nil, :asc
        end
      end

      def lt(value)
        @lt = "(#{@index.score_for_value(value)}"
        self
      end

      def lte(value)
        @lt = @index.score_for_value(value)
        self
      end

      def gt(value)
        @gt = "(#{@index.score_for_value(value)}"
        self
      end

      def gte(value)
        @gt = @index.score_for_value(value)
        self
      end

      def order(value)
        unless [:asc, :desc].include?(value)
          raise InvalidQueryOption.new("order must be :asc or :desc but was #{value.inspect}")
        end

        @order = value
        self
      end

      def limit(value)
        @limit = value
        self
      end

      def offset(value)
        @offset = value
        self
      end

      def zrangebyscore_limit
        # zrangebyscore uses offset/count rather than start/stop like zrange
        offset, stop = @index.range_from_options(@redis, offset: @offset, limit: @limit)
        count = stop == -1 ? -1 : (stop - offset + 1)
        [offset, count]
      end

      def lookup
        command, score_1, score_2 = case @order
          when :desc then [:zrevrangebyscore, @lt, @gt]
          when :asc  then [:zrangebyscore,    @gt, @lt]
        end

        @redis.send(command, @index.sorted_set_name, score_1, score_2, limit: zrangebyscore_limit)
      end
    end
  end

  register_index OrderedIndex
  class InvalidQueryOption < Relix::Error; end
end

