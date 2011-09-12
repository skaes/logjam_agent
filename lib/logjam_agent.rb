require "logjam_agent/version"
require "logjam_agent/amqp_forwarder"
require "logjam_agent/forwarders"
require "logjam_agent/request"
require "logjam_agent/buffered_logger"
require "logjam_agent/syslog_like_formatter"

module LogjamAgent

  class ForwardingError < StandardError; end

  mattr_accessor :error_handler
  self.error_handler = lambda { |exception| }

  mattr_accessor :application_name
  self.application_name = nil

  mattr_accessor :environment_name
  self.environment_name = nil

  def self.disable!
    self.disabled = true
  end

  def self.enable!
    self.disabled = false
  end

  mattr_accessor :disabled
  self.disabled = false
end
