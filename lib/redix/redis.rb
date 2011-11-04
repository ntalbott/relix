require 'hiredis'
require 'redis'

module Redix
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
end