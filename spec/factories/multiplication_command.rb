class MultiplicationCommand
  prepend EasyCommand

  def call
    @a * @b
  end

  def initialize(a,b)
    @a = a
    @b = b
  end
end
