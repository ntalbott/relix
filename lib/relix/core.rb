module Relix
  def self.included(klass)
    super
    klass.extend ClassMethods
  end

  def self.index_types
    @index_types ||= {}
  end

  def self.register_index(index)
    index_types[index.kind.to_sym] = index
  end

  module ClassMethods
    def relix(&block)
      @relix ||= IndexSet.new(self, Relix)
      if block_given?
        @relix.instance_eval(&block)
      else
        @relix
      end
    end

    def lookup(&block)
      relix.lookup(&block)
    end

    def lookup_values(index)
      relix.lookup_values(index)
    end

    def lookup_count(index)
      relix.count(index)
    end

    def deindex_by_primary_key!(pk)
      relix.deindex_by_primary_key!(pk)
    end
  end

  def relix
    self.class.relix
  end

  def index!
    relix.index!(self)
  end

  def deindex!
    relix.deindex!(self)
  end

  class Error < StandardError; end
end
