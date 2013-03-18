module Relix
  VERSION = "1.5.0"
  REDIS_VERSION = "2.6"

  class Version
    include Comparable

    attr_reader :major, :minor, :patch
    def initialize(version)
      @major, @minor, @patch = version.to_s.split(".").collect{|e| e.to_i}
      @minor ||= 0
      @patch ||= 0
    end

    def <=>(other)
      case other
      when String
        (self <=> Version.new(other))
      else
        if((r = (major <=> other.major)) != 0)
          r
        elsif((r = (minor <=> other.minor)) != 0)
          r
        else
          (patch <=> other.patch)
        end
      end
    end
  end

  def self.deprecate(message, as_of_version)
    as_of_version = Version.new(as_of_version)

    if Version.new(VERSION).major > as_of_version.major
      raise DeprecationError.new(message)
    else
      $stderr.puts(message)
    end
  end

  class DeprecationError < Exception; end
end
