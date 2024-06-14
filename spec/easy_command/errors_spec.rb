require 'spec_helper'

require 'ostruct'

describe EasyCommand::Errors do
  let(:errors) { described_class.new }

  describe '#add' do
    it 'adds the error' do
      errors.add :attribute, :some_error, 'some error description'
      expect(errors[:attribute]).to eq([{ code: :some_error, message: 'some error description' }])
    end

    it 'adds the same error only once' do
      errors.add :attribute, :some_error, 'some error description'
      errors.add :attribute, :some_error, 'some error description'

      expect(errors[:attribute]).to eq([{ code: :some_error, message: 'some error description' }])
    end

    it 'tries to localize the error message if possible' do
      expect(I18n).to receive(:t!).with(:bad_post_code, anything).and_return("Very bad post code")

      errors.add :address, :invalid, :bad_post_code
      expect(errors[:address]).to eq([{ code: :invalid, message: "Very bad post code" }])
    end

    it 'symbolizes the code' do
      errors.add :attribute, 'some_error', 'some error description'
      expect(errors[:attribute]).to eq([{ code: :some_error, message: 'some error description' }])
    end

    context 'when the errors are for a i18n-scoped class' do
      let(:scoped_klass) { Class.new { prepend EasyCommand }.tap { |c| c.i18n_scope = 'my.custom.scope' } }
      let(:errors) { described_class.new(source: scoped_klass) }

      it "takes the scope into account for localization" do
        allow(I18n).to receive(:t!).with(:bad_post_code, anything).
          and_return("Bad error message")
        expect(I18n).to receive(:t!).with(:bad_post_code, hash_including(scope: 'my.custom.scope')).
          and_return("Correct error message")

        errors.add :address, :invalid, :bad_post_code
        expect(errors[:address]).to eq([{ code: :invalid, message: "Correct error message" }])
      end
    end
  end

  describe '#exists?' do
    it "indicates if the attribute has a specific error", :aggregate_failures do
      expect(errors.exists?(:attribute, :some_error)).to eq(false)
      errors.add(:attribute, :some_error, 'some message')
      expect(errors.exists?(:attribute, :some_error)).to eq(true)
    end
  end

  describe '#merge_from' do
    # rubocop:disable Style/OpenStructUse
    # We use it to quickly-mock objects, it's specs-only, that's fine

    it 'can import errors from object with similar error sets' do
      commandlike_object = OpenStruct.new(errors: described_class.new)
      commandlike_object.errors.add(:name, :bad_name, "Bad name!")

      errors.merge_from(commandlike_object)

      expect(errors).to have_key(:name)
      expect(errors[:name]).to include(code: :bad_name, message: "Bad name!")
    end

    it 'can import errors from any object responding to errors.details and errors.messages' do
      recordlike_object = OpenStruct.new(errors: OpenStruct.new(messages: {}, details: {}))
      recordlike_object.errors.messages[:name] = ["Bad name!"]
      recordlike_object.errors.details[:name] = [{ error: :bad_name }]

      errors.merge_from(recordlike_object)

      expect(errors).to have_key(:name)
      expect(errors[:name]).to include(code: :bad_name, message: "Bad name!")
    end
    # rubocop:enable Style/OpenStructUse
  end

  describe '#add_multiple_errors' do
    let(:errors_list) do
      {
        attribute_a: [{ code: :some_error, message: 'some error description' }],
        attribute_b: [{ code: :another_error, message: 'another error description' }],
      }
    end

    before do
      errors.add_multiple_errors errors_list
    end

    it 'populates itself with the added errors' do
      expect(errors[:attribute_a]).to eq(errors_list[:attribute_a])
      expect(errors[:attribute_b]).to eq(errors_list[:attribute_b])
    end
  end

  describe '#full_messages' do
    let(:errors_list) do
      {
        attribute_a: [
          { code: :some_error, message: 'some error description' },
          { code: :another_error, message: 'another error description' },
        ],
        attribute_b: [{ code: :another_error, message: 'another error description' }],
      }
    end

    before do
      errors.add_multiple_errors errors_list
    end

    it 'returns a messages array' do
      expect(errors.full_messages).to eq(["Attribute_a some error description", "Attribute_a another error description", "Attribute_b another error description"])
    end
  end
end
