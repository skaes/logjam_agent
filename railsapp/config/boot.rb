Warning[:deprecated] = false if RUBY_VERSION =~ /\A2.7/

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.
