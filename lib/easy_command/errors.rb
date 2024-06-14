module EasyCommand
  class NotImplementedError < ::StandardError; end

  class Errors < Hash
    attr_reader :source

    def initialize(source: nil)
      @source = source
      super()
    end

    def exists?(attribute, code)
      self.fetch(attribute, []).any? { |e| e[:code] == code }
    end
    alias_method :has_error?, :exists?

    def add(attribute, code, message_or_key = nil, **options)
      code = code.to_sym
      message_or_key ||= code

      if defined?(I18n)
        # Can't use `I18n.exists?` because it doesn't accept a scope: kwarg
        message = begin
          I18n.t!(message_or_key, scope: source&.i18n_scope, **options)
        rescue I18n::MissingTranslationData
          nil
        end
      end
      message ||= message_or_key

      self[attribute] ||= []
      self[attribute] << { code: code, message: message }
      self[attribute].uniq!
    end

    def merge_from(object)
      raise ArgumentError unless object.respond_to?(:errors)
      errors = if object.errors.respond_to?(:messages)
        object.errors.messages.each_with_object({}) do |(attribute, messages), object_errors|
          object_errors[attribute] = messages.
            zip(object.errors.details[attribute]).
            map { |message, detail| [detail[:error], message] }
        end
      else
        object.errors
      end

      add_multiple_errors(errors)
    end

    def add_multiple_errors(errors_hash)
      errors_hash.each do |key, values|
        values.each do |value|
          if value.is_a?(Hash)
            code = value[:code]
            message_or_key = value[:message]
          else
            code = value.first
            message_or_key = value.last || value.first
          end
          add(key, code, message_or_key)
        end
      end
    end

    # For SimpleCommand gem compatibility, to ease migration.
    def full_messages
      messages = []
      each do |attribute, errors|
        errors.each do |error|
          messages << full_message(attribute, error[:message])
        end
      end
      messages
    end

    def full_message(attribute, message)
      return message if attribute == :base
      attr_name = attribute.to_s.tr('.', '_').capitalize
      "%s %s" % [attr_name, message]
    end
  end
end
