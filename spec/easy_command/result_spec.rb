require 'spec_helper'

RSpec.describe EasyCommand::Result do
  let(:monad) { described_class.new(5) }

  it "carries a result" do
    expect(monad.result).to eq(5)
  end

  describe "default" do
    it "is a success" do
      expect(monad.success?).to eq(true)
    end

    it "isn't a failure" do
      expect(monad.failure?).to eq(false)
    end

    it "has no errors" do
      expect(monad.errors).to be_empty
    end
  end

  describe EasyCommand::Success do
    let(:monad) { described_class.new(5) }

    it "is a success" do
      expect(monad.success?).to eq(true)
    end

    it "isn't a failure" do
      expect(monad.failure?).to eq(false)
    end

    it "has no errors" do
      expect(monad.errors).to be_empty
    end
  end

  describe EasyCommand::Params do
    let(:monad) { described_class.new(5) }

    it "is a success" do
      expect(monad.success?).to eq(true)
    end

    it "isn't a failure" do
      expect(monad.failure?).to eq(false)
    end

    it "has no errors" do
      expect(monad.errors).to be_empty
    end
  end

  describe EasyCommand::Failure do
    let(:monad) { described_class.new(5) }

    it "isn't a success" do
      expect(monad.success?).to eq(false)
    end

    it "is a failure" do
      expect(monad.failure?).to eq(true)
    end

    it "can be instantiated with errors" do
      errors = EasyCommand::Errors.new
      errors.add(:attribute, :error)
      monad = described_class.new(nil).with_errors(errors)
      expect(monad.errors).to have_error(:attribute, :error)
    end
  end

  describe "callbacks" do
    describe "#on_success" do
      context "on Success monads" do
        let(:monad) { EasyCommand::Success.new(5) }

        it "executes the block" do
          block_executed = false
          monad.on_success do
            block_executed = true
          end
          expect(block_executed).to eq true
        end

        it "passes the content of the monad to the block" do
          monad.on_success do |arg|
            expect(arg).to eq(5)
          end
        end
      end

      context "on Failure monads" do
        let(:monad) { EasyCommand::Failure.new(5) }

        it "doesn't execute the block" do
          block_executed = false
          monad.on_success do
            block_executed = true
          end
          expect(block_executed).to eq false
        end
      end
    end

    describe "#on_failure" do
      context "on Success monads" do
        let(:monad) { EasyCommand::Success.new(5) }

        it "doesn't execute the block" do
          block_executed = false
          monad.on_failure do
            block_executed = true
          end
          expect(block_executed).to eq false
        end
      end

      context "on Failure monads" do
        let(:errors) { EasyCommand::Errors.new.tap { |err| err.add :attribute, :code } }
        let(:monad) { EasyCommand::Failure.new(5).with_errors(errors) }

        it "executes the block" do
          block_executed = false
          monad.on_failure do
            block_executed = true
          end
          expect(block_executed).to eq true
        end

        it "passes the content of the monad to the block" do
          monad.on_failure do |arg|
            expect(arg).to eq(errors)
          end
        end
      end
    end
  end

  describe "chaining mechanism" do
    let(:callable_object) do
      Class.new { def self.call(*); :toto end }
    end

    it "calls the chained object" do
      expect(callable_object).to receive(:call)
      monad.then(callable_object)
    end

    it "passes its own result to the call" do
      allow(callable_object).to receive(:call) do |arg|
        expect(arg).to eq 5
      end
      monad.then(callable_object)
    end

    it "returns the result of the call" do
      expect(monad.then(callable_object)).to eq(:toto)
    end

    context "in case of failure" do
      let(:monad) { EasyCommand::Failure.new(nil) }

      it "doesn't call the chained object" do
        expect(callable_object).not_to receive(:call)
        monad.then(callable_object)
      end

      it "returns itself" do
        expect(monad.then(callable_object)).to eq(monad)
      end
    end
  end
end
