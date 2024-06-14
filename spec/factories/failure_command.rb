class FailureCommand
  prepend EasyCommand

  def initialize(input)
    @input = input
  end

  def call
    errors.add(:base, :some_error, 'Error message')
    @input * 2
  end
end
