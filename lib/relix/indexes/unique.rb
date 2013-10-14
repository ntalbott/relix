module Relix
  class UniqueIndex < Index
    include Ordering

    def sorted_set_name
      @set.keyer.component(name, 'ordering')
    end

    def hash_name
      @set.keyer.component(name, 'lookup')
    end

    def watch_keys(*values)
      hash_name
    end

    def filter(r, pk, object, value)
      v = r.hget(hash_name, value)
      if(v && (v != pk))
        raise NotUniqueError.new("'#{value}' is not unique in index #{name}")
      end
      super
    end

    def index?(r, object, value)
      return false if read(object).values.any?{|e| e.nil?}
      super
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

    def deindex(r, pk, old_value)
      r.hdel(hash_name, old_value)
      r.zrem(sorted_set_name, pk)
    end

    def destroy_all(r)
      r.del(hash_name)
      r.del(sorted_set_name)
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
