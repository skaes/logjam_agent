require 'simplecov'
SimpleCov.start do
  add_filter %r{^/test/}
end

require "logger"
require 'minitest/autorun'
require 'minitest/unit'
require 'minitest/pride' if ENV['RAINBOW_COLORED_TESTS'] == "1" && $stdout.tty?
require 'mocha/minitest'

class MiniTest::Test
  require "active_support/testing/declarative"
  extend ActiveSupport::Testing::Declarative
end

$:.unshift File.expand_path('../../lib', __FILE__)
require "logjam_agent"
require "logjam_agent/receiver"

# for Sinatra
ENV['RACK_ENV'] = "test"

# Obfuscate the foo cookie.
LogjamAgent.obfuscated_cookies = [/\A(foo|.*_session)\z/]

class MockLogDev
  attr_reader :lines
  def initialize
    @lines = []
  end
  def write(s)
    @lines << s
  end
end
