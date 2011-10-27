require 'hiredis'
require 'redis'

module Redix
  def self.included(klass)
    super
    klass.extend ClassMethods
  end

  module ClassMethods
    def redix(&block)
      @redix ||= Model.new(self)
      if block_given?
        @redix.instance_eval(&block)
      else
        @redix
      end
    end

    def lookup(&block)
      redix.lookup(&block)
    end
  end

  def redix
    self.class.redix
  end

  def index!
    redix.index!(self)
  end

  class Query
    def initialize(model)
      @model = model
      @offset = 0
    end

    def [](index_name)
      index = @model.indexes[index_name.to_s]
      raise MissingIndexError.new("No index declared for #{index_name}") unless index
      @clause = Clause.new(index)
    end

    def run
      if @clause
        @clause.lookup
      else
        @model.indexes['primary_key'].lookup
      end
    end

    class Clause
      def initialize(index)
        @index = index
        @options = {}
      end

      def eq(value, options={})
        @value = value
        @options = options
      end

      def all(options={})
        @all = true
        @options = options
      end

      def lookup
        if @all
          @index.all(@options)
        else
          @index.eq(@value, @options)
        end
      end
    end
  end

  class Model
    attr_reader :indexes
    def initialize(klass)
      @klass = klass
      @indexes = Hash.new
    end

    def primary_key(accessor)
      @primary_key = add_index(:primary_key, 'primary_key', on: accessor)
    end
    alias pk primary_key

    def multi(name, options={})
      add_index(:multi, name, options)
    end

    def unique(name, options={})
      add_index(:unique, name, options)
    end

    def add_index(index_type, name, options={})
      accessor = (options.delete(:on) || name)
      @indexes[name.to_s] = INDEX_TYPES[index_type].new(accessor, key_prefix(name), options)
    end

    def lookup(&block)
      raise MissingPrimaryKeyError.new("You must declare a primary key for #{@klass.name}") unless @primary_key
      if block
        query = Query.new(self)
        yield(query)
        query.run
      else
        @primary_key.all
      end
    end

    def index!(object)
      pk = read_primary_key(object)
      current_values_name = "#{key_prefix('current_values')}:#{pk}"

      Redix.redis do |r|
        loop do
          r.watch current_values_name
          current_values = r.hgetall(current_values_name)
          indexers = []
          @indexes.each do |name,index|
            ((watch = index.watch) && r.watch(*watch))

            value = index.read(object)
            old_value = current_values[name]

            next if value == old_value
            current_values[name] = value

            next if index.skip?(r, pk, value)

            query_value = index.query(r, value)
            indexers << proc do
              index.index(r, pk, object, value, old_value, *query_value)
            end
          end
          result = r.multi do
            indexers.each do |indexer|
              indexer.call
            end
            r.hmset(current_values_name, *current_values.flatten)
          end
          break if result
        end
      end
    end

    def key_prefix(name)
      "#{@klass.name}:#{name}"
    end

    def read_primary_key(object)
      @primary_key.read(object)
    end
  end

  class Index
    def initialize(accessor, name, options={})
      @name = "#{kind}:#{name}"
      @accessor = accessor
      @options = options
    end

    def read(object)
      object.send(@accessor)
    end

    def watch
      nil
    end

    def skip?(r, pk, value)
      false
    end

    def query(r, value)
      nil
    end

    def key_for(value)
      "#{@name}:#{value}"
    end
  end

  module Ordering
    def initialize(*args)
      super
      @order = @options[:order]
    end

    def score(object, value)
      if @order
        object.send(@order)
      else
        case value
        when Numeric
          value
        else
          value.to_i
        end
      end
    end

    def range_from_options(options)
      start = (options[:offset] || 0)
      stop = (options[:limit] ? (start + options[:limit] - 1) : -1)
      [start, stop]
    end
  end

  class MultiIndex < Index
    include Ordering

    def index(r, pk, object, value, old_value)
      r.zadd(key_for(value), score(object, value), pk)
      r.zrem(key_for(old_value), pk)
    end

    def eq(value, options={})
      Redix.redis.zrange(key_for(value), *range_from_options(options))
    end

    def kind
      "multi"
    end
  end

  class UniqueIndex < Index
    include Ordering

    def initialize(*args)
      super
      @set_name = "#{@name}:set"
      @sorted_set_name = "#{@name}:zset"
      @hash_name = "#{@name}:hash"
    end

    def watch
      [@set_name, @hash_name]
    end

    def skip?(r, pk, value)
      if r.sismember(@set_name, value)
        raise NotUniqueError.new("'#{value}'' is not unique in index #{@name}")
      end
      false
    end

    def index(r, pk, object, value, old_value)
      r.hset(@hash_name, value, pk)
      r.hdel(@hash_name, old_value)
      r.zadd(@sorted_set_name, score(object, value), pk)
      r.sadd(@set_name, value)
    end

    def all(options={})
      Redix.redis.zrange(@sorted_set_name, *range_from_options(options))
    end

    def eq(value, options={})
      [Redix.redis.hget(@hash_name, value)].compact
    end

    def kind
      "unique"
    end
  end

  class PrimaryKeyIndex < Index
    include Ordering

    def watch
      @name
    end

    def skip?(r, pk, value)
      r.zrank(@name, pk)
    end

    def query(r, value)
      r.zcard(@name)
    end

    def index(r, pk, object, value, old_value, rank)
      r.zadd(@name, rank, pk)
    end

    def all(options={})
      Redix.redis.zrange(@name, *range_from_options(options))
    end

    def eq(value, options)
      [value]
    end

    def kind
      "primary_key"
    end
  end

  INDEX_TYPES = {
    primary_key: PrimaryKeyIndex,
    multi: MultiIndex,
    unique: UniqueIndex,
  }

  def self.redis
    unless @redis
      @redis = ::Redis.new(port: @redis_port)
      @redis.select @redis_db if @redis_db
    end
    if block_given?
      yield(@redis)
    else
      @redis
    end
  end

  def self.port=(value)
    @redis_port = value
  end

  def self.db=(value)
    @redis_db = value
  end

  class IndexNotUniqueError < StandardError; end
  class MissingIndexError < StandardError; end
  class MissingPrimaryKeyError < StandardError; end
  class NotUniqueError < StandardError; end
end