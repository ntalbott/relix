module Relix
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
    def relix(&block)
      @relix ||= IndexSet.new(self, Relix.redis)
      if block_given?
        @relix.instance_eval(&block)
      else
        @relix
      end
    end

    def lookup(&block)
      relix.lookup(&block)
    end
  end

  def relix
    self.class.relix
  end

  def index!
    relix.index!(self)
  end
end