require 'logjam_agent'

module LogjamAgent

  module Rack
    autoload :Logger, 'logjam_agent/rack/logger'
  end
  autoload :Middleware, 'logjam_agent/middleware'

  class Railtie < Rails::Railtie

    initializer "initialize_logjam_agent_logger", :before => :initialize_logger do |app|
      Rails.logger ||= app.config.logger ||
        begin
          rails_version = Rails::VERSION::STRING
          paths = app.config.paths
          path = (rails_version < "3.2" ? paths.log.to_a : paths['log']).first.to_s
          logger = LogjamAgent::BufferedLogger.new(path)
          logger.level = ActiveSupport::BufferedLogger.const_get(app.config.log_level.to_s.upcase)
          logger.formatter = LogjamAgent::SyslogLikeFormatter.new
          logger.auto_flushing = false if Rails.env.production? && rails_version < "3.2"
          logger
        rescue StandardError => e
          logger = LogjamAgent::BufferedLogger.new(STDERR)
          logger.level = ActiveSupport::BufferedLogger::WARN
          logger.warn(
                      "Logging Error: Unable to access log file. Please ensure that #{path} exists and is writable. " +
                      "The log level has been raised to WARN and the output directed to STDERR until the problem is fixed."
                      )
          logger
        end
    end

    initializer "logjam_agent", :after => "time_bandits" do |app|
      app.config.middleware.swap("TimeBandits::Rack::Logger", "LogjamAgent::Rack::Logger")
      app.config.middleware.insert_before("LogjamAgent::Rack::Logger", "LogjamAgent::Middleware")
    end

  end
end

