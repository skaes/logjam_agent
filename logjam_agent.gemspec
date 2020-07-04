# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "logjam_agent/version"

Gem::Specification.new do |s|
  s.name        = "logjam_agent"
  s.version     = LogjamAgent::VERSION
  s.authors     = ["Stefan Kaes"]
  s.email       = ["stefan.kaes@xing.com"]
  s.homepage    = "https://github.com/skaes/logjam_agent"
  s.summary     = %q{Logjam client library to be used with logjam}
  s.description = %q{Logjam logger and request information forwarding}

  s.files         = Dir['README.md', 'Rakefile', 'lib/**/*.rb']
  s.test_files    = Dir['test/**/*.rb']
  s.executables   = []
  s.require_paths = ["lib"]

  s.add_development_dependency "rake"
  s.add_development_dependency "i18n"
  s.add_development_dependency "snappy"
  s.add_development_dependency "lz4-ruby"
  s.add_development_dependency "oj"
  s.add_development_dependency "byebug"
  s.add_development_dependency "minitest"
  s.add_development_dependency "mocha"
  s.add_development_dependency "sinatra"
  s.add_development_dependency "rack-test"
  s.add_development_dependency "appraisal"

  s.add_runtime_dependency "activesupport"
  s.add_runtime_dependency "time_bandits", [">= 0.12.1"]
  s.add_runtime_dependency "ffi-rzmq-core", [">= 1.0.5"]
  s.add_runtime_dependency "ffi-rzmq", [">= 2.0.4"]
end
