# rubocop:disable Naming/FileName
# rubocop:enable Naming/FileName
# frozen_string_literal: true

module EasyCommand
  class Result
    module ClassMethods
      def [](*args, **kwargs)
        new(*args, **kwargs)
      end
    end
    extend ClassMethods
  end

  module ClassMethods
    def call(*args, **kwargs)
      new(*args, **kwargs).call
    end
  end

  def abort(*args, **kwargs)
    errors.add(*args, **kwargs)
    raise ExitError
  end

  module LegacyErrorHandling
    # Convenience/retrocompatibility aliases
    def self.errors_legacy_alias(method, errors_method)
      define_method method do |*args, **kwargs|
        warn "/!\\ #{method} is deprecated, please use errors.#{errors_method} instead."
        errors.__send__ errors_method, *args, **kwargs
      end
    end
  end

  def assert_subcommand(klass, *args, **kwargs)
    command_instance = klass.new(*args, **kwargs).as_sub_command
    (@sub_commands ||= []) << command_instance
    command = command_instance.call
    return command.result if command.success?
    errors.merge_from(command)
    raise ExitError.new(result: command.result)
  end

  def assert_sub(...)
    warn "/!\\ 'assert_sub' is deprecated, please use 'assert_subcommand' instead."
    assert_subcommand(...)
  end
end
