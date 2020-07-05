ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require 'logjam_agent/receiver'

LogjamAgent.enable!

class ActiveSupport::TestCase
  fixtures :all
end
