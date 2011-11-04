module Redix
  def self.included(klass)
    super
    klass.extend ClassMethods
  end

  def self.index_types
    @index_types ||= {}
  end

  def self.register_index(name, index)
    index_types[name.to_sym] = index
  end

  module ClassMethods
    def redix(&block)
      @redix ||= IndexSet.new(self)
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
end