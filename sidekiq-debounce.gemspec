# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sidekiq/debounce/version'

Gem::Specification.new do |spec|
  spec.name          = 'sidekiq-debounce'
  spec.version       = Sidekiq::Debounce::VERSION
  spec.authors       = ['Peter Lejeck']
  spec.email         = ['me@plejeck.com']
  spec.summary       = 'A client-side middleware for debouncing Sidekiq jobs'
  spec.description   = <<-DESC
Sidekiq::Debounce provides a way to rate-limit creation of Sidekiq jobs.  When
you create a job on a Worker with debounce enabled, Sidekiq::Debounce will
delay the job until the debounce period has elapsed with no additional debounce
calls. If you make another job with the same arguments before the specified
time has elapsed, the timer is reset and the entire period must pass again
before the job is executed.
DESC
  spec.homepage      = 'https://github.com/NuckChorris/sidekiq-debounce'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^spec/})
  spec.require_paths = ['lib']

  spec.add_dependency 'sidekiq', '>= 3.0'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'mock_redis'
  spec.add_development_dependency 'mocha'
  spec.add_development_dependency 'codeclimate-test-reporter'
end
