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
          paths = app.config.paths
          path = (Rails::VERSION::STRING < "3.1" ? paths.log.to_a : paths['log']).first.to_s
          logger = LogjamAgent::BufferedLogger.new(path)
          logger.level = ::Logger.const_get(app.config.log_level.to_s.upcase)
          logger.formatter = LogjamAgent::SyslogLikeFormatter.new
          logger.auto_flushing = false if Rails.env.production? && Rails::VERSION::STRING < "3.2"
          logger = ActiveSupport::TaggedLogging.new(logger) if Rails::VERSION::STRING >= "3.2"
          logger
        rescue StandardError
          logger = LogjamAgent::BufferedLogger.new(STDERR)
          logger = ActiveSupport::TaggedLogging.new(logger) if Rails::VERSION::STRING >= "3.2"
          logger.level = ::Logger::WARN
          logger.warn(
                      "Logging Error: Unable to access log file. Please ensure that #{path} exists and is writable. " +
                      "The log level has been raised to WARN and the output directed to STDERR until the problem is fixed."
                      )
          logger
        end
      if Rails::VERSION::STRING < "3.2"
        at_exit { Rails.logger.flush if Rails.logger.respond_to?(:flush) }
      end
    end

    initializer "logjam_agent", :after => "time_bandits" do |app|
      app.config.middleware.swap("TimeBandits::Rack::Logger", "LogjamAgent::Rack::Logger")
      app.config.middleware.insert_before("LogjamAgent::Rack::Logger", "LogjamAgent::Middleware")
    end

    # make
    ActiveSupport.on_load(:action_controller) do
      ActionDispatch::Http::UploadedFile.class_eval <<-"EVA"
        def to_hash
          {
            :original_filename => original_filename,
            :content_type => content_type,
            :headers => headers,
            :tempfile => { :path => tempfile.path }
          }
        end
      EVA
    end
  end
end

