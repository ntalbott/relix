require 'hiredis'
require 'redis'

module Relix
  def self.redis
    unless @redis
      @redis = new_redis_client
    end
    if block_given?
      yield(@redis)
    else
      @redis
    end
  end

  def self.new_redis_client
    ::Redis.new(host: @redis_host, port: @redis_port).tap do |client|
      version = client.info["redis_version"]
      if(Relix::Version.new(version) < Relix::REDIS_VERSION)
        raise UnsupportedRedisVersion.new("Relix requires Redis >= #{Relix::REDIS_VERSION}; you have #{version}.")
      end
      client.select @redis_db if @redis_db
    end
  end

  def self.host=(value)
    @redis_host = value
  end

  def self.port=(value)
    @redis_port = value
  end

  def self.db=(value)
    @redis_db = value
  end

  class UnsupportedRedisVersion < Exception; end
end
