# rubocop:disable Naming/FileName
# rubocop:enable Naming/FileName
# frozen_string_literal: true

module EasyCommand
  class Result
    module ClassMethods
      def [](*args)
        new(*args)
      end
    end
    extend ClassMethods
  end

  module ClassMethods
    def call(*args)
      new(*args).call
    end
  end

  def abort(*args)
    errors.add(*args)
    raise ExitError
  end

  def assert(*_args)
    raise ExitError if errors.any?
  end

  module LegacyErrorHandling
    # Convenience/retrocompatibility aliases
    def self.errors_legacy_alias(method, errors_method)
      define_method method do |*args|
        warn "/!\\ #{method} is deprecated, please use errors.#{errors_method} instead."
        errors.__send__ errors_method, *args
      end
    end
  end

  def assert_subcommand(klass, *args)
    command_instance = klass.new(*args).as_sub_command
    (@sub_commands ||= []) << command_instance
    command = command_instance.call
    return command.result if command.success?
    errors.merge_from(command)
    raise ExitError.new(result: command.result)
  end

  def assert_sub(klass, *args)
    warn "/!\\ 'assert_sub' is deprecated, please use 'assert_subcommand' instead."
    assert_subcommand(klass, *args)
  end
end
