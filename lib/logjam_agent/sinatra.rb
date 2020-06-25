require 'sinatra'
require 'logger'
require 'logjam_agent'
require 'logjam_agent/middleware'
require 'logjam_agent/rack/sinatra_request'
require 'logjam_agent/rack/logger'
require 'time_bandits'

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
      logfile = settings.respond_to?(:logfile) ? settings.logfile : "#{settings.root}/#{settings.environment}.log"
      puts logfile
      logger = LogjamAgent::BufferedLogger.new(logfile)
      loglevel = settings.respond_to?(:loglevel) ? settings.loglevel : :info
      logger.level = ::Logger.const_get(loglevel.to_s.upcase)
      LogjamAgent.log_device_log_level = logger.level
      logger.formatter = LogjamAgent::SyslogLikeFormatter.new
      logger = ActiveSupport::TaggedLogging.new(logger)
      LogjamAgent.logger = logger
      ActiveSupport::LogSubscriber.logger = logger
    end

    def self.registered(app)
      app.helpers Logjam::Helpers

      app.use LogjamAgent::Middleware, :sinatra
      app.use LogjamAgent::Rack::Logger

      LogjamAgent.environment_name = app.settings.environment

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
