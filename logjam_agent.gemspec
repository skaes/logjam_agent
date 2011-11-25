# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "logjam_agent/version"

Gem::Specification.new do |s|
  s.name        = "logjam_agent"
  s.version     = LogjamAgent::VERSION
  s.authors     = ["Stefan Kaes"]
  s.email       = ["stefan.kaes@xing.com"]
  s.homepage    = ""
  s.summary     = %q{Logjam client library to be used with logjam}
  s.description = %q{Logjam logger and request information forwarding}

  s.rubyforge_project = "logjam_agent"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "rake"
  s.add_development_dependency "i18n"

  s.add_runtime_dependency "activesupport"
  s.add_runtime_dependency "uuid4r"
  s.add_runtime_dependency "time_bandits", [">= 0.1.1"]
end
