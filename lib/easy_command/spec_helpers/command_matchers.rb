# frozen_string_literal: true

# TODO: Rewrite this as a pure module definition to remove dependency on RSpec
require 'rspec/matchers'

=begin
it { expect(Extinguishers::PayloadValidator).to have_been_called_with_acp(payload) }
it { is_expected.to be_failure }
it { is_expected.to have_failed }
it { is_expected.to have_failed.with_error(:date, :invalid) }
it { is_expected.to have_failed.with_error(:date, :invalid, "The format must be iso8601") }
it { is_expected.to have_error(:date, :invalid) }
it { is_expected.to have_error(:date, :invalid, "The format must be iso8601") }
=end
module EasyCommand
  module SpecHelpers
    module CommandMatchers
      extend RSpec::Matchers::DSL

      matcher :have_been_called_with_action_controller_parameters do
        match(notify_expectation_failures: true) do |command_class|
          expect(command_class).to have_received(:call).
            with(an_instance_of(ActionController::Parameters)) do |params|
              expect(params.to_unsafe_h).to match(payload)
            end
        end
      end
      alias_matcher :have_been_called_with_ac_parameters , :have_been_called_with_action_controller_parameters
      alias_matcher :have_been_called_with_acp , :have_been_called_with_action_controller_parameters

      matcher :have_failed do
        match(notify_expectation_failures: true) do |result|
          expect(result).to have_error(@key, @code, @message) if @key.presence
          result.failure?
        rescue RSpec::Expectations::ExpectationNotMetError => e
          @matcher_error_message = e.message
          false
        end

        chain :with_error do |key, code, message = nil|
          @key = key
          @code = code
          @message = message
        end

        failure_message do
          @matcher_error_message
        end
      end

      matcher :have_error do
        match do |result|
          if message.presence
            result.errors[key]&.include?(code: code, message: message)
          else
            result.errors.exists?(key, code)
          end
        end

        failure_message do
          err = "expected #{command_name} to have errors on #{to_txt key} with code #{to_txt code}"
          err += " and message #{to_txt message}" if message.present?
          err += "\nactual error for #{to_txt key}: #{@actual.errors[key] || 'nil'}"
          err
        end

        def command_name
          actual.class.name
        end

        def key
          expected.first
        end

        def code
          expected.second
        end

        def message
          expected.third
        end

        def to_txt(value)
          value.is_a?(Symbol) ? ":#{value}" : "\"#{value}\""
        end
      end
    end
  end
end
