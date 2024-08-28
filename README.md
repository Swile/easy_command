# EasyCommand

A simple, standardized way to build and use _Service Objects_ in Ruby.

Table of Contents
=================

* [Requirements](#requirements)
* [Installation](#installation)
* [Contributing](#contributing)
* [Publication](#publication)
   * [Automated](#automated)
* [Usage](#usage)
   * [Returned objects](#returned-objects)
   * [Subcommand](#subcommand)
   * [Command chaining](#command-chaining)
      * [Flow success callbacks](#flow-success-callbacks)
   * [Merge errors from ActiveRecord instance](#merge-errors-from-activerecord-instance)
   * [Stopping execution of the command](#stopping-execution-of-the-command)
      * [abort](#abort)
      * [assert](#assert)
      * [ExitError](#exiterror)
   * [Callback](#callback)
      * [#on_success](#on_success)
   * [Error message](#error-message)
      * [Default scope](#default-scope)
      * [Example](#example)
* [Test with Rspec](#test-with-rspec)
   * [Mock](#mock)
      * [Setup](#setup)
      * [Usage](#usage-1)
   * [Matchers](#matchers)
      * [Setup](#setup-1)
      * [Rails project](#rails-project)
      * [Usage](#usage-2)
* [Using as Command](#using-as-command)
* [Acknowledgements](#acknowledgements)

<!-- Created by https://github.com/ekalinin/github-markdown-toc -->

# Requirements

* At least Ruby 2.0+

It is currently used at Swile with Ruby 2.7 and Ruby 3 projects.

# Installation

Add this line to your application's Gemfile:

```ruby
gem 'easy_command'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install easy_command

# Contributing

To ensure that our automatic release management system works perfectly, it is important to:

- strictly use conventional commits naming: https://github.com/googleapis/release-please#how-should-i-write-my-commits
- verify that all PRs name are compliant with conventional commits naming before squash-merging it into master

Please note that we are using auto release.

# Publication

## Automated

Gem publishing and releasing is now automated with [google-release-please](https://github.com/googleapis/release-please).

The exact configuration of the workflow can be found in `.github/workflows/release.yml`

# Usage

Here's a basic example of a command that check if a collection is empty or not

```ruby
# define a command class
class CollectionChecker
  # put Command before the class' ancestors chain
  prepend EasyCommand

  # mandatory: define a #call method. its return value will be available
  #            through #result
  def call
    @collection.empty? || errors.add(:collection, :failure, "Your collection is empty !.")
    @collection.length
  end

  private

  # optional, initialize the command with some arguments
  # optional, initialize can be public or private, private is better ;-)
  def initialize(collection)
    @collection = collection
  end
end
```
Then, in your controller:

```ruby
class CollectionController < ApplicationController
  def create
    # initialize and execute the command
    command = CollectionChecker.call(params)

    # check command outcome
    if command.success?
      # command#result will contain the number of items, if any
      render json: { count: command.result }
    else
      render_error(
        message: "Payload is empty.",
        details: command.errors,
      )
    end
  end

  private

  def render_error(details:, message: "Bad request", code: "BAD_REQUEST", status: 400)
    payload = {
      error: {
        code: code,
        message: message,
        details: details,
      }
    }
    render status: status, json: payload
  end
end
```

When errors, the controller will return the following json :

```json
{
  "error": {
    "code": "BAD_REQUEST",
    "message": "Payload is empty",
    "details": {
      "collection": [
        {
          "code": "failure",
          "message": "Your collection is empty !."
        }
      ]
    }
  }
}
```

## Returned objects

The EasyCommands' return values make use of the  Result monad.
An EasyCommand will always return an `EasyCommand::Result` (either as an `EasyCommand::Success` or as an `EasyCommand::Failure`) which are easy to manipulate and to interface with. These objects both answer to `#success?`, `#failure?`, `#result` and `#errors` (with `#result` being the return value of the `#call` method by default).

This means that the mechanisms described below ([Subcommand](#subcommand) and [Command chaining](#command-chaining)) are
easily extendable and can be made compatible with objects that make use of them.

## Subcommand

It is also possible to call sub command and stop run if failed :
```ruby
class CollectionChecker
  prepend EasyCommand

  def initialize(collection)
    @collection = collection
  end

  def call
    assert_subcommand FormatChecker, @collection
    @collection.empty? || errors.add(:collection, :failure, "Your collection is empty !.")
    @collection.length
  end
end

class FormatChecker
  prepend EasyCommand

  def call
    @collection.is_a?(Array) || errors.add(:collection, :failure, "Not an array")
    @collection.class.name
  end

  def initialize(collection)
    @collection = collection
  end
end

command = CollectionChecker.call('foo')
command.success? # => false
command.failure? # => true
command.errors # => { collection: [ { code: :failure, message: "Not an array" } ] }
command.result # => nil
```

You can get result from your sub command :
```ruby
class CrossProduct
  prepend EasyCommand

  def call
    product = assert_subcommand Multiply, @first, 100
    product / @second
  end

  def initialize(first, second)
    @first = first
    @second = second
  end
end

class Multiply
  def call
    @first * @second
  end
  # ...
end
```

## Command chaining

Since EasyCommands are made to encapsulate a specific, unitary action it is frequent to need to chain them to represent a
logical flow. To do this, a `then` method has been provided (also aliased as `|`). This will feed the result of the
initial EasyCommand as the parameters of the following EasyCommand, and stop the execution is any error is encountered during
the flow.

This is compatible out-of-the-box with any object that answers to `#call` and returns a `EasyCommand::Result` (or similar
object).

```ruby
class CreateUser
  prepend EasyCommand

  def call
    puts "User #{@name} created!"
    {
      name: @name,
      email: "#{@name.downcase}@swile.co"
    }
  end

  def initialize(name)
    @name = name
  end
end

class Emailer
  prepend EasyCommand

  def call
    send_email
    @user
  end

  def send_email
    puts "Sending email at #{@email}"
    if $mail_service_down
      errors.add(:email, :delivery_error, "Couldn't send email to #{@email}")
    end
  end

  def initialize(user)
    @user = user
    @email = @user[:email]
  end
end

class NotifyOtherServices
  prepend EasyCommand

  def call
    puts "User created: #{@user}"
    @user
  end

  def initialize(user)
    @user = user
  end
end

$mail_service_down = false
user_flow = EasyCommand::Params['Michel'] |
  CreateUser |
  Emailer |
  NotifyOtherServices
# User Michel created !
# Sending email at michel@swile.co
# User created: { name: 'Michel', email: 'michel@swile.co' }
# => <EasyCommand::Success @result={ name: 'Michel', email: 'michel@swile.co' }>

$mail_service_down = true
user_flow = EasyCommand::Params['Michel'] |
  CreateUser |
  Emailer |
  NotifyOtherServices
# User Michel created !
# Sending email at michel@swile.co
# => <EasyCommand::Error @errors={ email: [{code: :delivery_error, message: "Couldn't send email to michel@swile.co"}] }>
```

`EasyCommand::Params` is provided as a convenience object to encapsulate the initial params to feed into the flow for
readability, but `user_flow = CreateUser.call('Michel') | Emailer | NotifyOtherServices` would have been functionally
equivalent.

### Flow success callbacks

Since it is also common to react differently according to the result of the flow, convenience callback definition
methods are provided:

```ruby
user_flow.
  on_success do |user|
    puts "Process done without issues ! 🎉"
    LaunchOnboardingProcess.call(user)
  end.
  on_failure do |errors|
    puts "Encountered errors: #{errors}"
    NotifyFailureToAdmin.call(errors)
  end
```

## Merge errors from ActiveRecord instance
```ruby
class UserCreator
  prepend EasyCommand

  def call
    @user.save!
  rescue ActiveRecord::RecordInvalid
    merge_errors_from_record(@user)
  end
end

invalid_user = User.new
command = UserCreator.call(invalid_user)
command.success? # => false
command.failure? # => true
command.errors # => { name: [ { code: :required, message: "must exist" } ] }
```

## Stopping execution of the command

To avoid the verbosity of numerous `return` statements, you have three alternative ways to stop the execution of a
command:

### abort
```ruby
class FormatChecker
  prepend EasyCommand

  def call
    abort :collection, :failure, "Not an array" unless @collection.is_a?(Array)
    @collection.class.name
  end

  def initialize(collection)
    @collection = collection
  end
end

command = FormatChecker.call("not array")
command.success? # => false
command.failure? # => true
command.errors # => { collection: [ { code: :failure, message: "Not an array" } ] }
```

It also accepts a `result:` parameter to give the Failure object a value.
```ruby
# ...
    abort :collection, :failure, "Not an array", result: @collection
# ...

command = FormatChecker.call(my_custom_object)
command.result # => my_custom_object
```

### assert
```ruby
class UserDestroyer
  prepend EasyCommand

  def call
    assert check_if_user_is_destroyable
    @user.destroy!
  end

  def check_if_user_is_destroyable
    errors.add :user, :active, "Can't destroy active users" if @user.projects.active.any?
    errors.add :user, :sole_admin, "Can't destroy last admin" if @user.admin? && User.admin.count == 1
  end
end

invalid_user = User.admin.with_active_projects.first
command = UserDestroyer.call(invalid_user)
command.success? # => false
command.failure? # => true
command.errors # => { user: [
#   { code: :active, message: "Can't destroy active users" },
#   { code: :sole_admin, message: "Can't destroy last admin" }
# ] }
```

It also accepts a `result:` parameter to give the Failure object a value.
```ruby
# ...
    assert check_if_user_is_destroyable, result: @user
# ...

command = UserDestroyer.call(invalid_user)
command.result # => invalid_user
```


### ExitError

Raising an `ExitError` anywhere during `#call`'s execution will stop the command, this is not recommended but can be
used to develop your own failure helpers. It can be initialized with a `code` and `message` optional parameters and a named parameter `result:` to give the Failure object a value.

## Callback

Sometimes, you need to deport action, after all command and sub commands are executed.
It is useful to send email or broadcast notification when all operation succeeded.
To make this possible, you can use `#on_success` callback.

### #on_success

This callback works through `assert_sub` when using sub command system.
**Note: the `on_success` callback of a command will be executed as soon as the
subcommand is done if it the command is`call`ed directly instead of through `assert_sub`**
Examples are better than many words :wink:.

```ruby
class Updater
  def call; end
  def on_success
    puts "#{self.class.name}##{__method__}"
  end
end

class CarUpdater < Updater
  prepend EasyCommand
end

class BikeUpdater < Updater
  prepend EasyCommand
end

class SkateUpdater < Updater
  prepend EasyCommand
  def call
    abort :skate, :broken
  end
end

class SuccessfulVehicleUpdater < Updater
  prepend EasyCommand
  def call
    assert_sub CarUpdater
    assert_sub BikeUpdater
  end
end

class FailedVehicleUpdater < Updater
  prepend EasyCommand
  def call
    assert_sub BikeUpdater
    assert_sub SkateUpdater
  end
end

SuccessfulVehicleUpdater.call
# CarUpdater#on_success
# BikeUpdater#on_success
# SuccessfulVehicleUpdater#on_success

FailedVehicleUpdater.call
# "nothing"
```


## Error message

The third parameter is the message.
```ruby
errors.add(:item, :invalid, 'It is invalid !')
```

A symbol can be used and the sentence will be generated with I18n (if it is loaded) :
```ruby
errors.add(:item, :invalid, :invalid_item)
```

Scope can be used with symbol :
```ruby
errors.add(:item, :invalid, :'errors.invalid_item')
# equivalent to
errors.add(:item, :invalid, :invalid_item, scope: :errors)
```

Error message is optional when adding error :
```ruby
errors.add(:item, :invalid)
```

is equivalent to
```ruby
errors.add(:item, :invalid, :invalid)
```

### Default scope

Inside an EasyCommand class, you can specify a base I18n scope by calling the class method `#i18n_scope=`, it will be the
default scope used to localize error messages during `errors.add`. Default value is `errors.messages`.

### Example
```yaml
# config/locales/en.yml
en:
  errors:
    messages:
      date:
        invalid: "Invalid date (yyyy-mm-dd)"
      invalid: "Invalid value"
  activerecord:
    messages:
      invalid: "Invalid record"
```

```ruby
# config/locales/en.yml

class CommandWithDefaultScope
  prepend EasyCommand

  def call
    errors.add(:generic_attribute, :invalid) # Identical to errors.add(:generic_attribute, :invalid, :invalid)
    errors.add(:date_attribute, :invalid, 'date.invalid')
  end
end
CommandWithDefaultScope.call.errors == {
  generic_attribute: [{ code: :invalid, message: "Invalid value" }],
  date_attribute: [{ code: :invalid, message: "Invalid date (yyyy-mm-dd)" }],
}

class CommandWithCustomScope
  prepend EasyCommand

  self.i18n_scope = 'activerecord.messages'

  def call
    errors.add(:base, :invalid) # Identical to errors.add(:base_attribute, :invalid, :invalid)
  end
end
CommandWithCustomScope.call.errors == {
  base: [{ code: :invalid, message: "Invalid record" }],
}
```

# Test with Rspec
Make the spec file `spec/commands/collection_checker_spec.rb` like:

```ruby
describe CollectionChecker do
  subject { described_class.call(collection) }

  describe '.call' do
    context 'when the context is successful' do
      let(:collection) { [1] }

      it 'succeeds' do
        is_expected.to be_success
      end
    end

    context 'when the context is not successful' do
      let(:collection) { [] }

      it 'fails' do
        is_expected.to be_failure
      end
    end
  end
end
```

## Mock

To simplify your life, the gem come with mock helper.
You must include `EasyCommand::SpecHelpers::MockCommandHelper`in your code.

### Setup

To allow this, you must require the `spec_helpers` file and include them into your specs files :
```ruby
require 'easy_command/spec_helpers'
describe CollectionChecker do
  include EasyCommand::SpecHelpers::MockCommandHelper
  # ...
end
```

or directly in your `spec_helpers` :
```ruby
require 'easy_command/spec_helpers'
RSpec.configure do |config|
  config.include EasyCommand::SpecHelpers::MockCommandHelper
end
```

### Usage

You can mock a command, to be successful or to fail :
```ruby
describe "#mock_command" do
  subject { mock }

  context "to fail" do
    let(:mock) do
      mock_command(CollectionChecker,
        success: false,
        result: nil,
        errors: { collection: [ code: :empty, message: "Your collection is empty !" ] },
      )
    end

    it { is_expected.to be_failure }
    it { is_expected.to_not be_success }
    it { expect(subject.errors).to eql({ collection: [ code: :empty, message: "Your collection is empty !" ] }) }
    it { expect(subject.result).to be_nil }
  end

  context "to success" do
    let(:mock) do
      mock_command(CollectionChecker,
        success: true,
        result: 10,
        errors: {},
      )
    end

    it { is_expected.to_not be_failure }
    it { is_expected.to be_success }
    it { expect(subject.errors).to be_empty }
    it { expect(subject.result).to eql 10 }
  end
end
```

For an unsuccessful command, you can use a simpler mock :
```ruby
let(:mock) do
  mock_unsuccessful_command(CollectionChecker,
    errors: { collection: { empty: "Your collection is empty !" } }
  )
end
```

For a successful command, you can use a simpler mock :
```ruby
let(:mock) do
  mock_successful_command(CollectionChecker,
    result: 10
  )
end
```

You can also add a code block to your mock that will be executed once your command is called during the rspec example :
```ruby
let(:user) { build(:user) }
let(:other_model { create(:other_model) }
let(:mock) do
  mock_successful_command(UserUpdater,
    result: user
  ) { other_model.update!(foo: :bar) }
```

## Matchers

To simplify your life, the gem come with matchers.
You must include `EasyCommand::SpecHelpers::CommandMatchers`in your code.

### Setup

To allow this, you must require the `spec_helpers` file and include them into your specs files :
```ruby
require 'easy_command/spec_helpers'
describe CollectionChecker do
  include EasyCommand::SpecHelpers::CommandMatchers
  # ...
end
```

or directly in your `spec_helpers` :
```ruby
require 'easy_command/spec_helpers'
RSpec.configure do |config|
  config.include EasyCommand::SpecHelpers::CommandMatchers
end
```

### Rails project

Instead of above, you can include matchers only for specific classes, using inference

```ruby
require 'easy_command/spec_helpers'
RSpec::Rails::DIRECTORY_MAPPINGS[:class] = %w[spec classes]
RSpec.configure do |config|
  config.include EasyCommand::SpecHelpers::CommandMatchers, type: :class
end
```

### Usage
```ruby
subject { CollectionChecker.call({}) }

it { is_expected.to be_failure }
it { is_expected.to have_failed }
it { is_expected.to have_failed.with_error(:collection, :empty) }
it { is_expected.to have_failed.with_error(:collection, :empty, "Your collection is empty !") }
it { is_expected.to have_error(:collection, :empty) }
it { is_expected.to have_error(:collection, :empty, "Your collection is empty !") }

context "when called in a controller" do
  before { get :index }
  # the 3 matchers bellow are aliases
  it { expect(CollectionChecker).to have_been_called_with_action_controller_parameters(payload) }
  it { expect(CollectionChecker).to have_been_called_with_ac_parameters(payload) }
  it { expect(CollectionChecker).to have_been_called_with_acp(payload) }
end

```

# Using as `Command`

`EasyCommand` used to be called `Command`. While this was no issue for a private library, it could not stay named that
way as a public gem. For ease of use and to help smoother transitions, we provide another require entrypoint for the
library:
```ruby
  gem 'easy_command', require: 'easy_command/as_command'
```
Requiring `easy_command/as_command` defines a `Command` alias that should provide the same functionality as when the gem was named as such.

**⚠️ This overwrites the toplevel `Command` constant - be sure to use it safely.**

**Also: do remember that any other `require`s should still be updated to `easy_command` though.**
For example `require 'easy_command/spec_helpers'`.

# Acknowledgements

This gem is a fork of the [simple_command](https://github.com/nebulab/simple_command) gem. Thanks for their initial work.

We also thank all the contributors at Swile that took part in the internal development of this gem:
- Jérémie Bonal
- Alexandre Lamandé
- Champier Cyril
- Dorian Coffinet
- Guillaume Charneau
- Matthew Nguyen
- Benoît Barbe
- Cédric Murer
- Marine Sourin
- Jean-Yves Rivallan
- Houssem Eddine Bousselmi
- Julien Bouyoud
- Didier Bernaudeau
- Charles Duporge
- Pierre-Julien D'alberto
