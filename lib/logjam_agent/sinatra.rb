require 'sinatra'
require 'logger'
require 'logjam_agent'
require 'logjam_agent/middleware'
require 'logjam_agent/rack/sinatra_request'
require 'logjam_agent/rack/logger'

module Sinatra
  module Logjam
    module Helpers
      def action_name(action_name)
        LogjamAgent.request.fields[:action] = action_name
      end

      def logger
        LogjamAgent.logger
      end
    end

    def setup_logjam_logger
      log_path = ENV["APP_LOG_TO_STDOUT"].present? ? STDOUT : "#{settings.root}/log/#{LogjamAgent.environment_name}.log"
      logger = LogjamAgent::BufferedLogger.new(log_path)
      loglevel = settings.respond_to?(:loglevel) ? settings.loglevel : :info
      logger.level = ::Logger.const_get(loglevel.to_s.upcase)
      LogjamAgent.log_device_log_level = logger.level
      logger.formatter = LogjamAgent::SyslogLikeFormatter.new
      logger = ActiveSupport::TaggedLogging.new(logger)
      LogjamAgent.logger = logger
      ActiveSupport::LogSubscriber.logger = logger

      # install a default error handler for forwarding errors
      log_path = ENV["APP_LOG_TO_STDOUT"].present? ? STDOUT : "#{settings.root}/log/logjam_agent_error.log"
      begin
        forwarding_error_logger = ::Logger.new(log_path)
      rescue StandardError
        forwarding_error_logger = ::Logger.new(STDERR)
      end
      forwarding_error_logger.level = ::Logger::ERROR
      forwarding_error_logger.formatter = ::Logger::Formatter.new
      LogjamAgent.forwarding_error_logger = forwarding_error_logger
    end

    def self.registered(app)
      app.helpers Logjam::Helpers

      app.use LogjamAgent::Middleware, :sinatra
      app.use LogjamAgent::Rack::Logger

      LogjamAgent.environment_name = ENV['LOGJAM_ENV'] || ENV['APP_ENV'] || app.settings.environment.to_s
      LogjamAgent.auto_detect_logged_exceptions

      app.enable :logging
    end
  end

  register Logjam
end

# Define exception, but doen' do anything about it. Sneaky!
module ActionDispatch
  module RemoteIp
    class IpSpoofAttackError < StandardError; end
  end
end
