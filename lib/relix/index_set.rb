module Relix
  class IndexSet
    attr_accessor :redis
    attr_reader :klass
    def initialize(klass, redis_source)
      @klass = klass
      @redis_source = redis_source
      @indexes = Hash.new
      @obsolete_indexes = Hash.new
      @keyer = Keyer.default_for(@klass) unless parent
    end

    def redis
      @redis ||= @redis_source.redis
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

    def keyer(value=nil, options={})
      if value
        @keyer = value.new(@klass, options)
      else
        (@keyer || parent.keyer)
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
      raise Relix::InvalidIndexError.new("Index #{name} is already declared as obsolete.") if @obsolete_indexes[name.to_s]

      @indexes[name.to_s] = create_index(self, index_type, name, options)
    end

    class Obsolater
      def initialize(index_set)
        @index_set = index_set
      end

      def method_missing(m, *args)
        if Relix.index_types.keys.include?(m.to_sym)
          @index_set.add_obsolete_index(m, *args)
        else
          raise ArgumentError.new("Unknown index type #{m}.")
        end
      end
    end

    def obsolete(&block)
      raise ArgumentError.new("No block passed.") unless block_given?

      Obsolater.new(self).instance_eval(&block)
    end

    def add_obsolete_index(index_type, name, options={})
      raise Relix::InvalidIndexError.new("Primary key indexes cannot be obsoleted.") if(index_type == :primary_key)
      raise Relix::InvalidIndexError.new("Index #{name} is already declared as non-obsolete.") if @indexes[name.to_s]

      @obsolete_indexes[name.to_s] = create_index(self, index_type, name, options)
    end

    def destroy_index(name)
      name = name.to_s
      index = @obsolete_indexes[name]
      raise MissingIndexError.new("No obsolete index found for #{name}.") unless index
      raise InvalidIndexError.new("Indexes built on immutable attributes cannot be destroyed.") if index.attribute_immutable?

      lookup.each do |pk|
        handle_concurrent_modifications(pk) do
          current_values_name = current_values_name(pk)
          redis.watch current_values_name
          current_values = redis.hgetall(current_values_name)

          old_value = current_values[name]

          ((watch = index.watch(old_value)) && !watch.empty? && redis.watch(*watch))
          ops = []
          ops << proc{ index.destroy(redis, pk, old_value) } if index.respond_to?(:destroy)
          ops << proc{ redis.hdel current_values_name, name }
          ops
        end
      end

      if index.respond_to?(:destroy_all)
        index.destroy_all(redis)
      end
    end

    def indexes
      Relix.deprecate("Calling #indexes is deprecated; use #[] instead.", "2")
      self
    end

    def lookup(&block)
      if block
        query = Query.new(self)
        yield(query)
        query.run
      else
        primary_key_index.all(redis)
      end
    end

    def lookup_values(index)
      self[index].values(redis)
    end

    def index_ops(object, pk)
      current_values_name = current_values_name(pk)
      redis.watch current_values_name
      current_values = redis.hgetall(current_values_name)
      new_current_values = {}

      ops = full_index_list.collect do |name,index|
        value = index.read_normalized(object)
        old_value = current_values[name]

        ((watch = index.watch(value, old_value)) && redis.watch(*watch))

        if index.index?(redis, object, value)
          new_current_values[name] = value unless index.attribute_immutable?
          next if value == old_value
          next unless index.filter(redis, object, value)

          query_value = index.query(redis, value)
          proc do
            index.index(redis, pk, object, value, old_value, *query_value)
          end
        else
          proc do
            index.deindex(redis, pk, old_value)
          end
        end
      end.compact

      if new_current_values.any?
        ops << proc do
          redis.hmset(current_values_name, *new_current_values.flatten)
        end
      elsif current_values.any?
        ops << proc do
          redis.del(current_values_name)
        end
      end

      ops
    end

    def index!(object)
      pk = primary_key_for(object)

      handle_concurrent_modifications(pk) do
        index_ops(object, pk)
      end
    end

    def deindex!(object)
      pk = primary_key_for(object)

      handle_concurrent_modifications(pk) do
        current_values_name = current_values_name(pk)
        redis.watch current_values_name
        current_values = redis.hgetall(current_values_name)

        full_index_list(:including_obsolete).map do |name, index|
          old_value = if index.attribute_immutable?
            index.read_normalized(object)
          else
            current_values[name]
          end

          ((watch = index.watch(old_value)) && !watch.empty? && redis.watch(*watch))
          proc { index.deindex(redis, pk, old_value) }
        end.tap { |ops| ops << proc { redis.del current_values_name } }
      end
    end

    def deindex_by_primary_key!(pk)
      handle_concurrent_modifications(pk) do
        current_values_name = current_values_name(pk)
        redis.watch current_values_name
        current_values = redis.hgetall(current_values_name)

        full_index_list(:including_obsolete).map do |name, index|
          old_value = current_values[name]

          ((watch = index.watch(old_value)) && !watch.empty? && redis.watch(*watch))
          proc { index.deindex(redis, pk, old_value) }
        end.tap { |ops| ops << proc { redis.del current_values_name } }
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

    def current_values_name(pk)
      keyer.values(pk, @klass)
    end

    def [](name)
      full_index_list[name.to_s]
    end

    protected

    def full_index_list(including_obsolete=false)
      list = (parent ? parent.full_index_list.merge(@indexes) : @indexes)
      if including_obsolete
        list = @obsolete_indexes.merge(list)
      end
      list
    end

    private

    def create_index(index_set, index_type, name, options)
      accessor = (options.delete(:on) || name)
      Relix.index_types[index_type].new(index_set, name, accessor, options)
    end

    def handle_concurrent_modifications(primary_key)
      retries = 5
      loop do
        ops = yield

        results = redis.multi do
          ops.each do |op|
            op.call(primary_key)
          end
        end

        if results
          Array(results).each do |result|
            raise RedisIndexingError.new(result.message) if Exception === result
          end
          break
        else
          retries -= 1
          raise ExceededRetriesForConcurrentWritesError.new if retries <= 0
        end
      end
    rescue Redis::CommandError => e
      raise RedisIndexingError, e.message, e.backtrace
    end

    def primary_key_for(object)
      primary_key_index.read_normalized(object)
    end
  end

  class MissingPrimaryKeyError < Relix::Error; end
  class RedisIndexingError < Relix::Error; end
  class ExceededRetriesForConcurrentWritesError < Relix::Error; end
  class InvalidIndexError < Relix::Error; end
end
