class SubCommand
  prepend EasyCommand

  def initialize(add_error: false)
    @add_error = add_error
    @execution_orders = []
  end

  def call
    errors.add(:something, :forbidden) if @add_error
  end

  def on_success
    code_execution __method__
  end

  def code_execution(method)
  end
end
