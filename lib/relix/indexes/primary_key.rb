module Relix
  class PrimaryKeyIndex < Index
    include Ordering

    def initialize(set, base_name, accessor, options={})
      options[:immutable_attribute] = true unless options.has_key?(:immutable_attribute)
      super
    end

    def watch_keys
      name
    end

    def filter(r, object, value)
      !r.zscore(name, value)
    end

    def query(r, value)
      r.zcard(name)
    end

    def index(r, pk, object, value, old_value, rank)
      r.zadd(name, rank, pk)
    end

    def deindex(r, pk, object, old_value)
      r.zrem(name, pk)
    end

    def all(r, options={})
      r.zrange(name, *range_from_options(r, options))
    end

    def eq(r, value, options)
      [value]
    end
  end
  register_index PrimaryKeyIndex
end
