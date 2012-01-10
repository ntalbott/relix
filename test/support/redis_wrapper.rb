class RedisWrapper
  def initialize(wrapped)
    @wrapped = wrapped
    @befores = {}
    @afters = {}
  end

  def before(method, &before)
    @befores[method.to_sym] = before
  end

  def after(method, &after)
    @afters[method.to_sym] = after
  end

  def method_missing(m, *args, &block)
    if @befores[m]
      @befores.delete(m).call(*args)
    end
    r = @wrapped.send(m, *args, &block)
    if @afters[m]
      @afters.delete(m).call(*args)
    end
    r
  end
end
