lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'easy_command/version'

Gem::Specification.new do |s|
  s.required_ruby_version = '>= 2.7'
  s.name          = 'easy_command'
  s.version       = EasyCommand::VERSION
  s.authors       = ['Swile']
  s.email         = ['ruby-maintainers@swile.co']
  s.summary       = 'Easy way to build and manage commands (service objects)'
  s.description   = 'Easy way to build and manage commands (service objects)'
  s.homepage      = 'http://github.com/Swile/easy-command'
  s.license       = 'MIT'

  s.metadata['rubygems_mfa_required'] = 'true'

  s.metadata["source_code_uri"] = "https://github.com/Swile/easy-command"
  s.metadata["github_repo"] = "ssh://github.com/Swile/easy-command"

  s.files         = `git ls-files -z`.split("\x0")
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_development_dependency 'bundler', '~> 2.0' # rubocop:disable Gemspec/DevelopmentDependencies
end
