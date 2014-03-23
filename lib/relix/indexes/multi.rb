module Relix
  class MultiIndex < Index
    include Ordering

    def watch_keys(*values)
      keys = values.compact.map { |v| key_for(v) }
      keys << values_key if index_values?
      keys
    end

    def index(r, pk, object, value, old_value)
      r.zadd(key_for(value), score(object, value), pk)
      index_value(r, value) if index_values?

      deindex(r, pk, old_value)
    end

    def deindex(r, pk, old_value)
      r.zrem(key_for(old_value), pk)
      deindex_value(r, old_value) if index_values?
    end

    def destroy(r, pk, old_value)
      r.del(key_for(old_value))
      r.destroy_values(r) if index_values?
    end

    def eq(r, value, options={})
      r.zrange(key_for(value), *range_from_options(r, options, value))
    end

    def position(r, pk, value)
      position = r.zrank(key_for(value), pk)
      raise MissingIndexValueError, "Cannot find key #{pk} in index for #{value}" unless position
      position
    end

    def count(r, value)
      r.zcard(key_for(normalize(value)))
    end

    def key_for(value)
      @set.keyer.component(name, value)
    end

    def index_values?
      @options[:index_values]
    end

    def values_key
      @set.keyer.component(name, "_values")
    end

    def values(r)
      raise ValuesNotIndexedError.new("Value indexing not enabled for #{name}.") unless index_values?
      r.smembers(values_key)
    end

    def index_value(r, value)
      r.sadd(values_key, value)
    end

    def deindex_value(r, old_value)
      r.eval %(
        if(redis.call("ZCARD", KEYS[2]) == 0) then
          return redis.call("SREM", KEYS[1], ARGV[1])
        end
        return "OK"
      ), [values_key, key_for(old_value)], [old_value]
    end

    def destroy_value(r)
      r.del(values_key)
    end
  end
  register_index MultiIndex
end
