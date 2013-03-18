module Relix
  VERSION = "1.5.0"
  REDIS_VERSION = "2.6"

  class Version
    include Comparable

    attr_reader :major, :minor, :patch
    def initialize(string)
      @major, @minor, @patch = string.split(".").collect{|e| e.to_i}
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
end
