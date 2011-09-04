require 'logjam_agent'
module LogjamAgent
  class Railtie < Rails::Railtie

    initializer "initialize_logjam_agent_logger", :before => :initialize_logger do |app|
      Rails.logger ||= app.config.logger ||
        begin
          path = app.config.paths.log.to_a.first
          logger = LogjamAgent::BufferedLogger.new(path)
          logger.level = ActiveSupport::BufferedLogger.const_get(app.config.log_level.to_s.upcase)
          logger.auto_flushing = false if Rails.env.production?
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

      ActiveSupport.on_load(:action_controller) do
        require 'logjam_agent/middleware.rb'
        require 'logjam_agent/rack/logger.rb'
      end
    end

  end
end

