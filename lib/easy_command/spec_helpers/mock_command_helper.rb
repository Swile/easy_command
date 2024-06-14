# frozen_string_literal: true

module EasyCommand
  module SpecHelpers
    module MockCommandHelper
      NO_PARAMS_PASSED = Object.new

      def mock_successful_command(command, result:, params: NO_PARAMS_PASSED)
        mock_command(command, success: true, result: result, params: params)
      end

=begin
    Example :
      mock_unsuccessful_command(ExtinguishDebtAndLetterIt, errors: {
        entry: { not_found: "Couldn't find Entry with 'document_identifier'='foo'" }
      })

    is equivalent to
      mock_command(ExtinguishDebtAndLetterIt,
        success: false,
        result: nil,
        errors: {:entry=>[code: :not_found, message: "Couldn't find Entry with 'document_identifier'='foo'"]},
      )
=end
      def mock_unsuccessful_command(command, errors:, params: NO_PARAMS_PASSED)
        mock_command(command, success: false, errors: detailed_errors(errors), params: params)
      end

      def mock_command(command, success:, result: nil, errors: {}, params: NO_PARAMS_PASSED)
        if Object.const_defined?('FakeCommandErrors')
          klass = Object.const_get('FakeCommandErrors')
        else
          klass = Object.const_set 'FakeCommandErrors', Class.new
          klass.prepend Command
        end
        fake_command = klass.new
        if errors.any?
          errors.each do |attr, details|
            details.each do |detail|
              fake_command.errors.add(attr, detail[:code], detail[:message])
            end
          end
        end
        double = instance_double(command)
        allow(double).to receive(:as_sub_command).and_return(double)
        allow(double).to receive(:errors).and_return(fake_command.errors)
        if success
          monad = Command::Success.new(result)
        else
          monad = Command::Failure.new(result).with_errors(fake_command.errors)
        end
        allow(double).to receive(:call).and_return(monad)
        allow(double).to receive(:on_success).and_return(double)
        if params == NO_PARAMS_PASSED
          allow(command).to receive(:call).and_return(monad)
          allow(command).to receive(:new).and_return(double)
        else
          mock_params, hash_params = extract_mock_params(params)
          allow(command).to receive(:call).with(*mock_params, **hash_params).and_return(monad)
          allow(command).to receive(:new).with(*mock_params, **hash_params).and_return(double)
        end
        double
      end

      private

      def extract_mock_params(params)
        if params.is_a? Array
          kw_params = if params.last.is_a? Hash
            params.pop
          else
            {}
          end
          [params, kw_params]
        else
          [[params], {}]
        end
      end

      def detailed_errors(errors)
        errors.to_h do |attribute, detail|
          [attribute, detail.map { |code, message| { code: code, message: message } }]
        end
      end
    end
  end
end
