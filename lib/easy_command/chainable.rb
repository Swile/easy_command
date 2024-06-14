module EasyCommand
  module Chainable
    def then(other)
      if success?
        other.call(result)
      else
        self
      end
    end
    alias_method :|, :then

    def self.included(klass)
      klass.define_method(:call) { self } unless klass.instance_methods.include? :call
    end
  end
end
