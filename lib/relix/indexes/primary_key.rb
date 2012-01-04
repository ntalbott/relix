module Relix
  class PrimaryKeyIndex < Index
    include Ordering

    def watch
      @name
    end

    def filter(r, object, value)
      !r.zrank(@name, value)
    end

    def query(r, value)
      r.zcard(@name)
    end

    def index(r, pk, object, value, old_value, rank)
      r.zadd(@name, rank, pk)
    end

    def all(options={})
      @set.redis.zrange(@name, *range_from_options(options))
    end

    def eq(value, options)
      [value]
    end
  end
  register_index :primary_key, PrimaryKeyIndex
end