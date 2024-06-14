class AddThenMultiplyCommand
  prepend EasyCommand

  def call
    sum = assert_subcommand AdditionCommand, @a, @b
    assert_subcommand MultiplicationCommand, sum, @c
  end

  def initialize(a,b,c)
    @a = a
    @b = b
    @c = c
  end
end
