module Relix
  class IndexSet
    attr_accessor :redis
    def initialize(klass, redis)
      @klass = klass
      @redis = redis
      @indexes = Hash.new
      @keyer = Keyer.default_for(@klass)
    end

    def primary_key(accessor)
      @primary_key_index = add_index(:primary_key, accessor)
    end
    alias pk primary_key

    def primary_key_index
      unless @primary_key_index
        if parent
          @primary_key_index = parent.primary_key_index
        else
          raise MissingPrimaryKeyError.new("You must declare a primary key for #{@klass.name}")
        end
      end
      @primary_key_index
    end

    def keyer(value=nil)
      if value
        @keyer = value.new(@klass)
      else
        @keyer
      end
    end

    def method_missing(m, *args)
      if Relix.index_types.keys.include?(m.to_sym)
        add_index(m, *args)
      else
        super
      end
    end

    def add_index(index_type, name, options={})
      accessor = (options.delete(:on) || name)
      @indexes[name.to_s] = Relix.index_types[index_type].new(self, name, accessor, options)
    end

    def indexes
      (parent ? parent.indexes.merge(@indexes) : @indexes)
    end

    def lookup(&block)
      if block
        query = Query.new(self)
        yield(query)
        query.run
      else
        primary_key_index.all
      end
    end

    def index_ops(object, pk)
      current_values_name = current_values_name(pk)
      @redis.watch current_values_name
      current_values = @redis.hgetall(current_values_name)

      ops = indexes.collect do |name,index|
        ((watch = index.watch) && @redis.watch(*watch))

        value = index.read_normalized(object)
        old_value = current_values[name]

        next if value == old_value
        current_values[name] = value

        next unless index.filter(@redis, object, value)

        query_value = index.query(@redis, value)
        proc do
          index.index(@redis, pk, object, value, old_value, *query_value)
        end
      end.compact

      ops << proc do
        @redis.hmset(current_values_name, *current_values.flatten)
      end

      ops
    end

    def index!(object)
      pk = primary_key_index.read_normalized(object)

      retries = 5
      loop do
        ops = index_ops(object, pk)
        results = @redis.multi do
          ops.each do |op|
            op.call(pk)
          end
        end
        if results
          results.each do |result|
            raise RedisIndexingError.new(result.message) if Exception === result
          end
          break
        else
          retries -= 1
          raise ExceededRetriesForConcurrentWritesError.new if retries <= 0
        end
      end
    end

    def current_values_name(pk)
      @keyer.values(pk)
    end

    def key_prefix(name)
      "#{@klass.name}:#{name}"
    end

    def parent
      unless @parent || @parent == false
        parent = @klass.superclass
        @parent = (parent.respond_to?(:relix) ? parent.relix : false)
      end
      @parent
    end
  end

  class MissingPrimaryKeyError < Relix::Error; end
  class RedisIndexingError < Relix::Error; end
  class ExceededRetriesForConcurrentWritesError < Relix::Error; end
end