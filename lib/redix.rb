require 'hiredis'
require 'redis'

module Redix
  def self.included(klass)
    super
    klass.extend ClassMethods
  end

  module ClassMethods
    def redix
      @redix ||= Model.new(self)
    end

    def primary_key(accessor)
      redix.primary_key(accessor)
    end

    def index(accessor)
      redix.index(accessor)
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
      @sort = :primary_key
      @clauses = []
    end

    def [](index_name)
      index = @model.indexes[index_name]
      raise MissingIndexError.new("No index declared for #{index_name}") unless index
      clause = Clause.new(self, index)
      @clauses << clause
      clause
    end

    def run
      results = @clauses.collect{|clause| clause.lookup}.inject{|result, accumulator| (result & accumulator)}
      results = @model.indexes[@sort].sort(results) if @sort
      results
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
      @indexes = {}
    end

    def primary_key(accessor)
      @primary_key = @indexes[:primary_key] = UniqueIndex.new(index_name("primary_key"), accessor)
    end

    def index(accessor)
      @indexes[accessor] = Index.new(index_name(accessor), accessor)
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
      @indexes.each do |_,index|
        index.index!(object, pk)
      end
    end

    def index_name(field_name)
      "#{@klass.name}:#{field_name}"
    end

    def read_primary_key(object)
      @primary_key.read(object)
    end
  end

  class Index
    def initialize(name, accessor)
      @name = name
      @accessor = accessor
    end

    def index!(object, pk)
      Redix.redis.sadd(key_for(read(object)), pk)
    end

    def eq(value)
      Redix.redis.smembers(key_for(value))
    end

    def read(object)
      object.send(@accessor)
    end

    def key_for(value)
      "#{@name}:#{value}"
    end
  end

  class UniqueIndex < Index
    def index!(object, pk)
      value = read(object)
      Redix.redis do |r|
        loop do
          r.watch @name
          if(r.zrank(@name, value))
            r.unwatch
            return
          end
          rank = r.zcard @name
          result = r.multi do
            r.zadd(@name, rank, value)
          end
          break if result
        end
      end
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
  end

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