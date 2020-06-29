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

# for Sinatra
ENV['RACK_ENV'] = "test"
