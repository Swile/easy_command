require 'simplecov'

SimpleCov.start do
  add_filter '/spec/'
end

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'easy_command'
require 'i18n'

I18n.load_path += Dir[File.expand_path("locales") + "/*.yml"]

Dir[File.join(File.dirname(__FILE__), 'factories', '**/*.rb')].each do |factory|
  require factory
end
