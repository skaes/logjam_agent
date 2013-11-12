require 'logjam_agent'

module LogjamAgent

  module Rack
    autoload :Logger, 'logjam_agent/rack/logger'
  end
  autoload :Middleware, 'logjam_agent/middleware'

  class Railtie < Rails::Railtie
    def logjam_log_path(app)
      paths = app.config.paths
      (Rails::VERSION::STRING < "3.1" ? paths.log.to_a : paths['log']).first.to_s
    end

    initializer "initialize_logjam_agent_logger", :before => :initialize_logger do |app|
      Rails.logger ||= app.config.logger ||
        begin
          path = logjam_log_path(app)
          logger = LogjamAgent::BufferedLogger.new(path)
          logger.level = ::Logger.const_get(app.config.log_level.to_s.upcase)
          logger.formatter = LogjamAgent::SyslogLikeFormatter.new
          logger.auto_flushing = false if Rails.env.production? && Rails::VERSION::STRING < "3.2"
          logger = ActiveSupport::TaggedLogging.new(logger) if Rails::VERSION::STRING >= "3.2"
          LogjamAgent.logger = logger
          logger
        rescue StandardError
          logger = LogjamAgent::BufferedLogger.new(STDERR)
          logger = ActiveSupport::TaggedLogging.new(logger) if Rails::VERSION::STRING >= "3.2"
          LogjamAgent.logger = logger
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
      LogjamAgent.environment_name = Rails.env
      LogjamAgent.auto_detect_logged_exceptions

      app.config.middleware.swap("TimeBandits::Rack::Logger", "LogjamAgent::Rack::Logger")
      app.config.middleware.insert_before("LogjamAgent::Rack::Logger", "LogjamAgent::Middleware")

      # install a default error handler for forwarding errors
      log_dir = File.dirname(logjam_log_path(app))
      forwarding_error_logger = ::Logger.new("#{log_dir}/logjam_agent_error.log")
      forwarding_error_logger.level = ::Logger::ERROR
      forwarding_error_logger.formatter = ::Logger::Formatter.new
      LogjamAgent.forwarding_error_logger = forwarding_error_logger

      # ignore asset requests in development
      LogjamAgent.ignore_asset_requests = Rails.env.development?

      # patch controller testing to create a logjam request, because middlewares aren't executed
      if Rails.env.test?
        ActiveSupport.on_load(:action_controller) do
          require 'action_controller/test_case'
          module ActionController::TestCase::Behavior
            def process_with_logjam(*args)
              LogjamAgent.start_request
              process_without_logjam(*args)
            ensure
              LogjamAgent.finish_request
            end
            alias_method_chain :process, :logjam
          end
        end
      end

      # patch rack so that the ip method returns the same result as rails remote_ip (modulo exceptions)
      app.config.after_initialize do
        if app.config.action_dispatch.trusted_proxies
          trusted_proxies = /^127\.0\.0\.1$|^(10|172\.(1[6-9]|2[0-9]|30|31)|192\.168)\.|^::1$|^fd[0-9a-f]{2}:.+|^localhost$/i
          trusted_proxies = Regexp.union(trusted_proxies, app.config.action_dispatch.trusted_proxies)
          ::Rack::Request.class_eval <<-"EVA"
            def trusted_proxy?(ip)
              ip =~ #{trusted_proxies.inspect}
            end
          EVA
        end

        ::Rack::Request.class_eval <<-EVA
          def ip
            remote_addrs = @env['REMOTE_ADDR'] ? @env['REMOTE_ADDR'].split(/[,\s]+/) : []
            remote_addrs.reject! { |addr| trusted_proxy?(addr) }

            return remote_addrs.first if remote_addrs.any?

            forwarded_ips = @env['HTTP_X_FORWARDED_FOR'] ? @env['HTTP_X_FORWARDED_FOR'].strip.split(/[,\s]+/) : []

            if client_ip = @env['HTTP_TRUE_CLIENT_IP'] || @env['HTTP_CLIENT_IP']
              # If forwarded_ips doesn't include the client_ip, it might be an
              # ip spoofing attempt, so we ignore HTTP_CLIENT_IP
              return client_ip if forwarded_ips.include?(client_ip)
            end

            return forwarded_ips.reject { |ip| trusted_proxy?(ip) }.last || @env["REMOTE_ADDR"]
          end
        EVA
      end
    end

    # avoid garbled tempfile information in the logs
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

