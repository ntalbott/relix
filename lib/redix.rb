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
      @sort = 'primary_key'
      @offset = 0
      @clauses = []
    end

    def [](index_name)
      index = @model.indexes[index_name.to_s]
      raise MissingIndexError.new("No index declared for #{index_name}") unless index
      clause = Clause.new(self, index)
      @clauses << clause
      clause
    end

    def run
      if @clauses.empty?
        results = @model.indexes['primary_key'].lookup
      else
        results = @clauses.collect{|clause| clause.lookup}.inject{|result, accumulator| (result & accumulator)}
      end
      results = @model.indexes[@sort.to_s].sort(results) if @sort
      if(@limit || @offset != 0)
        range_end = (@limit ? (@offset + @limit - 1) : -1)
        results = results[@offset..range_end]
      end
      results = results
      results
    end

    def sort(field)
      if field.to_s == 'primary_key'
        @sort = 'primary_key'
      else
        @sort = "#{field}_sort"
      end
      self
    end

    def limit(amount)
      @limit = amount.to_i
      self
    end

    def offset(index)
      @offset = index.to_i
      self
    end

    class Clause
      def initialize(query, index)
        @query = query
        @index = index
      end

      def eq(value)
        @value = value
        @query
      end

      def lookup
        @index.eq(@value)
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
      @primary_key = add_index(:primary_key, accessor, 'primary_key')
    end
    alias pk primary_key

    def multi(accessor)
      add_index(:multi, accessor)
    end

    def ordered(accessor)
      add_index(:ordered, accessor, "#{accessor}_sort")
    end

    def unique(accessor)
      add_index(:unique, accessor)
    end

    def add_index(index_type, accessor, name=accessor)
      @indexes[name.to_s] = INDEX_TYPES[index_type].new(accessor, key_prefix(name))
    end

    def lookup(&block)
      raise MissingPrimaryKeyError.new("You must declare a primary key for #{@klass.name}") unless @primary_key
      if block
        query = Query.new(self)
        yield(query)
        query.run
      else
        @primary_key.lookup
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

            next if index.skip?(r, value)

            query_value = index.query(r, value)
            indexers << proc do
              index.index(r, pk, value, old_value, *query_value)
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
    def initialize(accessor, name)
      @name = "#{kind}:#{name}"
      @accessor = accessor
    end

    def read(object)
      object.send(@accessor)
    end

    def watch
      nil
    end

    def skip?(r, value)
      false
    end

    def query(r, value)
      nil
    end

    def key_for(value)
      "#{@name}:#{value}"
    end
  end

  class MultiIndex < Index
    def index(r, pk, value, old_value)
      r.sadd(key_for(value), pk)
      r.srem(key_for(old_value), pk)
    end

    def eq(value)
      Redix.redis.smembers(key_for(value))
    end

    def kind
      "multi"
    end
  end

  class UniqueIndex < Index
    def watch
      @name
    end

    def skip?(r, value)
      r.zrank(@name, value)
    end

    def query(r, value)
      r.zcard(@name)
    end

    def index(r, pk, value, old_value, rank)
      r.zadd(@name, rank, value)
      r.zrem(@name, old_value)
    end

    def lookup
      Redix.redis.zrange(@name, 0, -1)
    end

    def eq(value)
      [value]
    end

    def sort(input)
      scores = Redix.redis do |r|
        r.multi do
          input.each{|e| r.zscore(@name, e)}
        end
      end
      result = []
      input.each_with_index do |e,i|
        result[scores[i].to_i] = e
      end
      result.compact
    end

    def kind
      "unique"
    end
  end

  class OrderedIndex < Index
    def index(r, pk, value, old_value)
      r.zadd(@name, rank(value), pk)
    end

    def sort(results)
      scores = Redix.redis do |r|
        r.multi do
          results.each{|e| r.zrank(@name, e)}
        end
      end
      result = []
      results.each_with_index do |e,i|
        result[scores[i].to_i] = e
      end
      result.compact
    end

    def rank(value)
      value.to_i
    end

    def kind
      "ordered"
    end
  end

  INDEX_TYPES = {
    primary_key: UniqueIndex,
    multi: MultiIndex,
    ordered: OrderedIndex,
    unique: UniqueIndex,
  }

  def self.redis
    @redis ||= ::Redis.new(port: @redis_port)
    if block_given?
      yield(@redis)
    else
      @redis
    end
  end

  def self.port=(value)
    @redis_port = value
  end

  class IndexNotUniqueError < StandardError; end
  class MissingIndexError < StandardError; end
  class MissingPrimaryKeyError < StandardError; end
end