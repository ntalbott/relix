module Redix
  class MultiIndex < Index
    include Ordering

    def index(r, pk, object, value, old_value)
      r.zadd(key_for(value), score(object, value), pk)
      r.zrem(key_for(old_value), pk)
    end

    def eq(value, options={})
      Redix.redis.zrange(key_for(value), *range_from_options(options, value))
    end

    def position(pk, value)
      position = Redix.redis.zrank(key_for(value), pk)
      raise MissingIndexValueError, "Cannot find key #{pk} in index for #{value}" unless position
      position
    end
  end
  register_index :multi, MultiIndex
end