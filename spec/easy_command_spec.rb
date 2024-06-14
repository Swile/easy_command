require 'spec_helper'

describe EasyCommand do
  let(:command) { SuccessCommand.new(2) }

  describe ".call" do
    before do
      allow(SuccessCommand).to receive(:new).and_return(command)
      allow(command).to receive(:call)
    end

    it "initializes the command" do
      expect(SuccessCommand).to receive(:new)

      SuccessCommand.call 2
    end

    it "calls #call method" do
      expect(command).to receive(:call)

      SuccessCommand.call 2
    end
  end

  describe "#call" do
    let(:missed_call_command) { MissedCallCommand.new(2) }

    it "returns a Success" do
      expect(command.call).to be_a(EasyCommand::Success)
    end

    it "raises an exception if the method is not defined in the command" do
      expect { missed_call_command.call }.to raise_error(EasyCommand::NotImplementedError)
    end

    it "returns a Failure if something went wrong" do
      command.errors.add(:some_error, 'some message')
      expect(command.call).to be_a(EasyCommand::Failure)
    end
  end

  describe '#abort' do
    let(:aborting_command) {
      Class.new do
        prepend EasyCommand

        def call
          abort :base, :some_error, 'Error message', result: 3
          raise "We shouldn't reach this" # rubocop:disable Lint/UnreachableCode
        end
      end
    }

    it "stops the execution as soon as it's called" do
      expect { aborting_command.call }.not_to raise_error
    end

    it "stops add the error passed as args" do
      expect(aborting_command.call.errors).to have_error(:base, :some_error)
    end

    it "stops let Failure carry the result" do
      expect(aborting_command.call.result).to eq(3)
    end
  end

  describe '#assert' do
    let(:asserting_command) {
      Class.new do
        prepend EasyCommand

        def initialize(should_error, with_result: false)
          @should_error = should_error
          @with_result = with_result
        end

        def call
          if @with_result
            assert potential_error, result: 4
          else
            assert potential_error
          end
          raise "We shouldn't reach this"
        end

        def potential_error
          if @should_error
            errors.add :base, :error1
            errors.add :base, :error2
          end
        end
      end
    }

    it "stops the execution as soon as it's called" do
      expect { asserting_command.call(true) }.not_to raise_error
    end

    it "adds the error passed as args" do
      expect(asserting_command.call(true).errors).
        to have_error(:base, :error1).
        and have_error(:base, :error2)
    end

    context "with a result along side the error" do
      it "lets Failure carry the result" do
        expect(asserting_command.call(true, with_result: true).result).to eq(4)
      end
    end
  end

  describe "#success?" do
    it "is true by default" do
      expect(command.call).to be_success
    end

    it "is false if something went wrong" do
      command.errors.add(:some_error, 'some message')
      expect(command.call).not_to be_success
    end
  end

  describe "#result" do
    it "returns the result of command execution" do
      expect(command.call.result).to eq(4)
    end

    context "when call is not called yet" do
      it "returns nil" do
        expect(command.result).to be_nil
      end
    end

    context "when command fails" do
      let(:command) { FailureCommand.new(2) }

      it "still returns the result" do
        expect(command.call.result).to eq(4)
      end
    end
  end

  describe "#failure?" do
    it "is false by default" do
      expect(command.call).not_to be_failure
    end

    it "is true if something went wrong" do
      command.errors.add(:some_error, 'some message')
      expect(command.call).to be_failure
    end
  end

  describe "#errors" do
    it "returns an EasyCommand::Errors" do
      expect(command.errors).to be_a(EasyCommand::Errors)
    end

    context "with no errors" do
      it "is empty" do
        expect(command.errors).to be_empty
      end
    end

    context "with errors" do
      before do
        command.errors.add(:attribute, :some_error, 'some message')
      end

      it "has a key with error message" do
        expect(command.errors[:attribute]).to eq([{ code: :some_error, message: 'some message' }])
      end
    end
  end

  describe "#has_error?" do
    it "indicates if the command has an error", :aggregate_failures do
      expect(command.has_error?(:attribute, :some_error)).to eq(false)
      command.errors.add(:attribute, :some_error, 'some message')
      expect(command.has_error?(:attribute, :some_error)).to eq(true)
    end
  end

  describe ".i18n_scope" do
    after do
      # Resetting to prevent leaks across specs
      command.class.i18n_scope = 'errors.messages'
    end

    it "has a default value of 'errors.messages'" do
      expect(command.class.i18n_scope).to eq('errors.messages')
    end

    it "can be overriden" do
      command.class.i18n_scope = 'errors.new_scope'
      expect(command.class.i18n_scope).to eq('errors.new_scope')
    end
  end

  describe "#on_success" do
    let(:command) { CallbackCommand.new(add_error: false) }

    before do
      allow(command).to receive(:call).and_call_original
      allow(command).to receive(:on_success).and_call_original
    end

    it "is executed after #call" do
      expect(command).to receive(:call).ordered
      expect(command).to receive(:on_success).ordered
      command.call
    end

    context "when there are errors" do
      let(:command) { CallbackCommand.new(add_error: true) }

      it "does not call #on_success" do
        expect(command).to receive(:call).ordered
        expect(command).not_to receive(:on_success)
        command.call
      end
    end

    context "when using sub command" do
      let(:command) { CallbackCommand.new(add_error: false, with_subcommand: true) }
      let(:subcommand) { SubCommand.new(add_error: false) }

      before do
        allow(SubCommand).to receive(:new).and_return(subcommand)
        allow(subcommand).to receive(:on_success).and_call_original
        allow(subcommand).to receive(:code_execution).and_call_original

        allow(command).to receive(:code_execution).and_call_original
      end

      specify "#on_success are called in order" do
        expect(command).to receive(:on_success).ordered
        expect(subcommand).to receive(:on_success).ordered
        command.call
      end

      specify "Sub command #on_success code are executed before parent" do
        expect(subcommand).to receive(:code_execution).ordered
        expect(command).to receive(:code_execution).ordered
        command.call
      end

      context "when parent has errors" do
        let(:command) { CallbackCommand.new(add_error: true) }

        it "does not call #on_success neither for parent nor for children" do
          expect(command).not_to receive(:on_success)
          expect(subcommand).not_to receive(:on_success)
          command.call
        end
      end

      context "when subcommand has error" do
        let(:subcommand) { SubCommand.new(add_error: true) }

        it "does not call #on_success neither for parents nor for children" do
          command.call
          expect(command).not_to receive(:on_success)
          expect(subcommand).not_to receive(:on_success)
        end
      end
    end
  end

  describe "Subcommmand mechanism" do
    it "can call other commands", :aggregate_failures do
      expect(AdditionCommand).to receive(:new).and_call_original
      expect(MultiplicationCommand).to receive(:new).and_call_original
      expect(AddThenMultiplyCommand.call(2, 3, 4).result).to eq(20)
    end

    context "when the first command fails" do
      before do
        double_addition = AdditionCommand.new(2, 3)
        allow(AdditionCommand).to receive(:new).and_return(double_addition)
        allow(double_addition).to receive(:call).and_wrap_original do |m, *|
          double_addition.errors.add(:addition, :failed)
          m.call
        end
      end

      it "merges the errors from the failing command in the calling command" do
        result = AddThenMultiplyCommand.call(2, 3, 4)
        expect(result.errors).to have_error(:addition, :failed)
      end

      it "stops the flow" do
        expect(MultiplicationCommand).not_to receive(:new)
        AddThenMultiplyCommand.call(2, 3, 4)
      end
    end
  end
end
