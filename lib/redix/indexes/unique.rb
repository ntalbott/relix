module Redix
  class UniqueIndex < Index
    include Ordering

    def initialize(*args)
      super
      @sorted_set_name = "#{@name}:zset"
      @hash_name = "#{@name}:hash"
    end

    def watch
      @hash_name
    end

    def filter(r, object, value)
      return true if read(object).values.any?{|e| e.nil?}
      if r.hexists(@hash_name, value)
        raise NotUniqueError.new("'#{value}' is not unique in index #{@name}")
      end
      true
    end

    def index(r, pk, object, value, old_value)
      if read(object).values.all?{|e| !e.nil?}
        r.hset(@hash_name, value, pk)
        r.zadd(@sorted_set_name, score(object, value), pk)
      else
        r.hdel(@hash_name, value)
        r.zrem(@sorted_set_name, pk)
      end
      r.hdel(@hash_name, old_value)
    end

    def all(options={})
      Redix.redis.zrange(@sorted_set_name, *range_from_options(options))
    end

    def eq(value, options={})
      [Redix.redis.hget(@hash_name, value)].compact
    end
  end
  register_index :unique, UniqueIndex

  class NotUniqueError < StandardError; end
end