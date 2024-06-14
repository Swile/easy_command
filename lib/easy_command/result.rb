require 'easy_command/chainable'

module EasyCommand
  class Result
    include Chainable

    def initialize(content)
      @content = content
    end

    def result
      @content
    end

    def errors
      EasyCommand::Errors.new
    end

    def failure?; false; end
    def success?; true; end

    def on_success
      yield(result) if success?
      self
    end

    def on_failure
      yield(errors) if failure?
      self
    end
  end

  class Success < Result; end

  class Params < Result; end

  class Failure < Result
    def success?; false; end
    def failure?; true; end

    def with_errors(errors)
      @_errors = errors
      self
    end

    def errors
      @_errors ||=
        EasyCommand::Errors.new.tap do |errors|
          errors.add(:result, :failure)
        end
    end
  end
end
