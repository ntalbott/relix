module Relix
  class MultiIndex < Index
    include Ordering

    def watch_keys(*values)
      values.compact.map { |v| key_for(v) }
    end

    def index(r, pk, object, value, old_value)
      r.zadd(key_for(value), score(object, value), pk)
      r.zrem(key_for(old_value), pk)
    end

    def deindex(r, pk, object, old_value)
      r.zrem(key_for(old_value), pk)
    end

    def eq(r, value, options={})
      r.zrange(key_for(value), *range_from_options(r, options, value))
    end

    def position(r, pk, value)
      position = r.zrank(key_for(value), pk)
      raise MissingIndexValueError, "Cannot find key #{pk} in index for #{value}" unless position
      position
    end

    def key_for(value)
      @set.keyer.component(name, value)
    end
  end
  register_index MultiIndex
end