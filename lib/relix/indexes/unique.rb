module Relix
  class UniqueIndex < Index
    include Ordering

    def sorted_set_name
      @set.keyer.component(name, 'ordering')
    end

    def hash_name
      @set.keyer.component(name, 'lookup')
    end

    def watch_keys
      hash_name
    end

    def filter(r, object, value)
      return true if read(object).values.any?{|e| e.nil?}
      if r.hexists(hash_name, value)
        raise NotUniqueError.new("'#{value}' is not unique in index #{name}")
      end
      true
    end

    def index(r, pk, object, value, old_value)
      if read(object).values.all?{|e| !e.nil?}
        r.hset(hash_name, value, pk)
        r.zadd(sorted_set_name, score(object, value), pk)
      else
        r.hdel(hash_name, value)
        r.zrem(sorted_set_name, pk)
      end
      r.hdel(hash_name, old_value)
    end

    def deindex(r, pk, object, old_value)
      r.hdel(hash_name, old_value)
      r.zrem(sorted_set_name, pk)
    end

    def all(r, options={})
      r.zrange(sorted_set_name, *range_from_options(r, options))
    end

    def eq(r, value, options={})
      [r.hget(hash_name, value)].compact
    end
  end
  register_index UniqueIndex

  class NotUniqueError < Relix::Error; end
end