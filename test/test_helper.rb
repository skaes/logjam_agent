require 'minitest/autorun'
require 'minitest/unit'
require 'minitest/pride' if ENV['RAINBOW_COLORED_TESTS'] == "1" && $stdout.tty?
require 'mocha/setup'

require_relative "../lib/logjam_agent"

class MiniTest::Test
  require "active_support/testing/declarative"
  extend ActiveSupport::Testing::Declarative
end
