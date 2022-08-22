require 'logjam_agent'

module LogjamAgent

  module Rack
    autoload :Logger, 'logjam_agent/rack/logger'
  end
  autoload :Middleware, 'logjam_agent/middleware'

  class Railtie < Rails::Railtie

    def logjam_log_path(app)
      app.config.paths['log'].first.to_s
    end

    initializer "initialize_logjam_agent_logger", :before => :initialize_logger do |app|
      Rails.logger ||= app.config.logger ||
        begin
          path = ENV["RAILS_LOG_TO_STDOUT"].present? ? STDOUT : logjam_log_path(app)
          logger = LogjamAgent::BufferedLogger.new(path)
          logger.formatter = LogjamAgent::SyslogLikeFormatter.new
          logger = ActiveSupport::TaggedLogging.new(logger)
          logger.level = ::Logger.const_get(app.config.log_level.to_s.upcase)
          LogjamAgent.log_device_log_level = logger.level
          LogjamAgent.logger = logger
        rescue StandardError
          logger = LogjamAgent::BufferedLogger.new(STDERR)
          logger = ActiveSupport::TaggedLogging.new(logger)
          logger.level = ::Logger::WARN
          logger.warn(
            "Logging Error: Unable to access log file. Please ensure that #{path} exists and is writable. " +
            "The log level has been raised to WARN and the output directed to STDERR until the problem is fixed."
          )
          LogjamAgent.logger = logger
        end
    end

    initializer "logjam_agent", :after => "time_bandits" do |app|
      LogjamAgent.environment_name = ENV['LOGJAM_ENV'] || Rails.env
      LogjamAgent.auto_detect_logged_exceptions

      app.config.middleware.swap(TimeBandits::Rack::Logger, LogjamAgent::Rack::Logger)
      app.config.middleware.insert_before(LogjamAgent::Rack::Logger, LogjamAgent::Middleware)

      if defined?(::ActionDispatch::RemoteIp)
        # see https://github.com/rails/rails/issues/26303
        class DummyMiddleware < Rails::Railtie; end
        app.config.middleware.swap ::ActionDispatch::RemoteIp, DummyMiddleware
        app.config.middleware.delete DummyMiddleware

        app.config.middleware.insert_before LogjamAgent::Middleware, ::ActionDispatch::RemoteIp, app.config.action_dispatch.ip_spoofing_check, app.config.action_dispatch.trusted_proxies
      else
        require 'logjam_agent/actionpack/lib/action_dispatch/middleware/remote_ip'
        app.config.middleware.insert_before LogjamAgent::Middleware, LogjamAgent::ActionDispatch::RemoteIp
      end

      # install a default error handler for forwarding errors
      log_path = ENV["RAILS_LOG_TO_STDOUT"].present? ? STDERR : File.dirname(logjam_log_path(app)) + "/logjam_agent_error.log"
      begin
        forwarding_error_logger = ::Logger.new(log_path)
      rescue StandardError
        forwarding_error_logger = ::Logger.new(STDERR)
      end
      forwarding_error_logger.level = ::Logger::ERROR
      forwarding_error_logger.formatter = ::Logger::Formatter.new
      LogjamAgent.forwarding_error_logger = forwarding_error_logger

      # ignore asset requests in development
      LogjamAgent.ignore_asset_requests = Rails.env.development?

      revision_file = File.join(app.root, 'REVISION')
      LogjamAgent.application_revision = File.exist?(revision_file) ? File.read(revision_file) : `git rev-parse HEAD 2>/dev/null`.chomp rescue ""

      # disable logjam request forwarding by default in test environment
      LogjamAgent.disable! if Rails.env.test?

      # only sent pings in production like environments
      LogjamAgent.ensure_ping_at_exit = !%w(test development).include?(Rails.env.to_s)

      # patch controller testing to create a logjam request, because middlewares aren't executed
      if Rails.env.test?
        ActiveSupport.on_load(:action_controller) do
          require 'action_controller/test_case'
          # Rails 5 fires on_load events multiple times, so we need to protect against endless recursion
          next if ActionController::TestCase::Behavior.instance_methods.include?(:process_without_logjam)
          module ActionController::TestCase::Behavior
            def process_with_logjam(action, **opts)
              LogjamAgent.start_request
              process_without_logjam(action, **opts)
            ensure
              LogjamAgent.finish_request
            end
            alias_method :process_without_logjam, :process
            alias_method :process, :process_with_logjam
          end
        end
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
            :tempfile => { :path => tempfile.path },
            :size => size
          }
        end
      EVA
    end

    if Rails::VERSION::STRING >= "5.0"
      # we want backtraces etc. logged as a single string with newlines.
      # TODO: when logging with tags, we might want to have tags and
      # timestamps on disk. Not sure how useful this would be, though.
      ActiveSupport.on_load(:action_controller) do
        ActionDispatch::DebugExceptions.class_eval do
          def log_error(request, wrapper)
            logger = logger(request)
            return unless logger

            exception = wrapper.exception

            trace = wrapper.application_trace
            trace = wrapper.framework_trace if trace.empty?

            ActiveSupport::Deprecation.silence do
              parts = [ "#{exception.class} (#{exception.message})" ]
              parts.concat exception.annoted_source_code if exception.respond_to?(:annoted_source_code)
              parts.concat trace
              logger.fatal parts.join("\n  ")
            end
          end
        end
      end
    end

    config.after_initialize do
      if LogjamAgent.ignore_render_events
        ActiveSupport::Notifications.unsubscribe("render_template.action_view")
        ActiveSupport::Notifications.unsubscribe("render_partial.action_view")
        ActiveSupport::Notifications.unsubscribe("render_collection.action_view")
      end

      truncate_overlong_params = lambda { |key, value|
        max_size = LogjamAgent.max_logged_size_for(key)
        if value.is_a?(String) && value.size > max_size
          value[max_size..-1] = " ... [TRUNCATED]"
        end
      }
      Rails.application.config.filter_parameters += [truncate_overlong_params]
    end
  end
end
