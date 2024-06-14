# frozen_string_literal: true

require 'byebug'
if RUBY_VERSION >= "3"
  require "easy_command/ruby-3-specific.rb"
elsif RUBY_VERSION.start_with? "2.7"
  require "easy_command/ruby-2-7-specific.rb"
else
  require "easy_command/ruby-2-specific.rb"
end

require 'easy_command/errors'
require 'easy_command/result'
require 'easy_command/version'

module EasyCommand
  class CommandError < RuntimeError
    attr_reader :code
    def initialize(message = nil, code = nil)
      @code = code
      super(message)
    end
  end
  class ExitError < CommandError
    attr_reader :result
    def initialize(message = nil, code = nil, result: nil)
      @result = result
      super(message, code)
    end
  end

  def self.prepended(base)
    base.extend ClassMethods
  end

  attr_reader :result

  module ClassMethods
    def self.extended(base)
      base.i18n_scope = "errors.messages"
    end
    attr_accessor :i18n_scope
  end

  def call
    fail NotImplementedError unless defined?(super)

    result = super
    if errors.none?
      on_success unless @as_sub_command
      Success[result]
    else
      Failure[result].with_errors(errors)
    end
  rescue ExitError => e
    Failure[@result || e.result].with_errors(errors)
  end

  def abort(*args, result: nil, **kwargs)
    errors.add(*args, **kwargs)
    raise ExitError.new(result: result)
  end

  def assert(*_args, result: nil)
    raise ExitError.new(result: result) if errors.any?
  end

  def errors
    @errors ||= EasyCommand::Errors.new(source: self.class)
  end

  def on_success
    (@sub_commands ||= []).each do |sub_command|
      sub_command.on_success
    end
    super if defined?(super)
  end

  module LegacyErrorHandling
    errors_legacy_alias :clear_errors, :clear
    errors_legacy_alias :add_error, :add
    errors_legacy_alias :merge_errors_from, :merge_from
    errors_legacy_alias :has_error?, :exists?
    errors_legacy_alias :full_errors, :itself
  end
  include LegacyErrorHandling

  def as_sub_command
    @as_sub_command = true
    self
  end
end
