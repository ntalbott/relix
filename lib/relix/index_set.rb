module Relix
  class IndexSet
    attr_accessor :redis
    def initialize(klass, redis)
      @klass = klass
      @redis = redis
      @indexes = Hash.new
    end

    def primary_key(accessor)
      add_index(:primary_key, 'primary_key', on: accessor)
    end
    alias pk primary_key

    def method_missing(m, *args)
      if Relix.index_types.keys.include?(m.to_sym)
        add_index(m, *args)
      else
        super
      end
    end

    def add_index(index_type, name, options={})
      accessor = (options.delete(:on) || name)
      @indexes[name.to_s] = Relix.index_types[index_type].new(self, key_prefix(name), accessor, options)
    end

    def indexes
      (parent ? parent.indexes.merge(@indexes) : @indexes)
    end

    def lookup(&block)
      unless primary_key = indexes['primary_key']
        raise MissingPrimaryKeyError.new("You must declare a primary key for #{@klass.name}")
      end
      if block
        query = Query.new(self)
        yield(query)
        query.run
      else
        primary_key.all
      end
    end

    def index!(object)
      unless primary_key_index = indexes['primary_key']
        raise MissingPrimaryKeyError.new("You must declare a primary key for #{@klass.name}")
      end
      pk = primary_key_index.read_normalized(object)
      current_values_name = "#{key_prefix('current_values')}:#{pk}"

      retries = 5
      loop do
        @redis.watch current_values_name
        current_values = @redis.hgetall(current_values_name)
        indexers = []
        indexes.each do |name,index|
          ((watch = index.watch) && @redis.watch(*watch))

          value = index.read_normalized(object)
          old_value = current_values[name]

          next if value == old_value
          current_values[name] = value

          next unless index.filter(@redis, object, value)

          query_value = index.query(@redis, value)
          indexers << proc do
            index.index(@redis, pk, object, value, old_value, *query_value)
          end
        end
        results = @redis.multi do
          indexers.each do |indexer|
            indexer.call
          end
          @redis.hmset(current_values_name, *current_values.flatten)
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

  class MissingPrimaryKeyError < StandardError; end
  class RedisIndexingError < StandardError; end
  class ExceededRetriesForConcurrentWritesError < StandardError; end
end