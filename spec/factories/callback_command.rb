class CallbackCommand
  prepend EasyCommand

  def initialize(add_error: false, with_subcommand: false)
    @add_error = add_error
    @with_subcommand = with_subcommand
  end

  def call
    assert_subcommand(SubCommand) if @with_subcommand
    errors.add(:something, :forbidden) if @add_error
  end

  def on_success
    code_execution __method__
  end

  def code_execution(method)
  end
end
