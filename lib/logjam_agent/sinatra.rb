require 'sinatra'
require 'logger'
require 'logjam_agent'
require 'logjam_agent/middleware'
require 'logjam_agent/rack/sinatra_request'
require 'logjam_agent/rack/logger'
require 'time_bandits'

module LogjamAgent
  module Sinatra
    class Middleware
      def initialize(app)
        app_with_logging = LogjamAgent::Rack::Logger.new(app)
        @app = LogjamAgent::Middleware.new(app_with_logging, :sinatra)
      end
      def call(env)
        @app.call(env)
      end
    end

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
      logger = LogjamAgent::BufferedLogger.new(log_path) rescue LogjamAgent::BufferedLogger.new(STDERR)

      loglevel = settings.respond_to?(:loglevel) ? settings.loglevel : :info
      logger.level = ::Logger.const_get(loglevel.to_s.upcase)

      LogjamAgent.log_device_log_level = logger.level
      LogjamAgent.log_device_log_level = ::Logger::ERROR unless %i[test development].include?(settings.environment.to_sym)

      logger.formatter = LogjamAgent::SyslogLikeFormatter.new
      logger = ActiveSupport::TaggedLogging.new(logger)
      LogjamAgent.logger = logger
      ActiveSupport::LogSubscriber.logger = logger

      log_path = ENV["APP_LOG_TO_STDOUT"].present? ? STDOUT : "#{settings.root}/log/logjam_agent_error.log"
      forwarding_error_logger = ::Logger.new(log_path) rescue ::Logger.new(STDERR)
      forwarding_error_logger.level = ::Logger::ERROR
      forwarding_error_logger.formatter = ::Logger::Formatter.new
      LogjamAgent.forwarding_error_logger = forwarding_error_logger

      truncate_overlong_params = lambda { |key, value|
        max_size = LogjamAgent.max_logged_size_for(key)
        if value.is_a?(String) && value.size > max_size
          value[max_size..-1] = " ... [TRUNCATED]"
        end
      }
      LogjamAgent.parameter_filters << truncate_overlong_params
    end

    def self.registered(app)
      app.helpers Helpers
      LogjamAgent.environment_name = ENV['LOGJAM_ENV'] || app.settings.environment.to_s
      LogjamAgent.auto_detect_logged_exceptions
      LogjamAgent.disable! if app.settings.environment.to_sym == :test
    end
  end
end

# For classic apps.
Sinatra.register LogjamAgent::Sinatra

# We already supply a logger.
Sinatra::Base.class_eval do
  class << self
    def setup_logging(builder); end
  end
end

# Patch Sinatra's render logic to compute corrected view times.
module LogjamAgent
  module ComputeRenderTimes
    def render(engine, data, options = {}, locals = {}, &block)
      consumed_before_rendering = TimeBandits.consumed
      result = exception = nil
      duration = Benchmark.ms do
        begin
          result = super
        rescue => exception
        end
      end
      consumed_during_rendering = TimeBandits.consumed - consumed_before_rendering
      duration -= consumed_during_rendering
      raise exception if exception
      result
    ensure
      Thread.current.thread_variable_set(
        :time_bandits_completed_info,
        [ duration, ["Views: %.3fms" % duration.to_f], duration, "" ]
      )
    end
  end
end

Sinatra::Base.prepend LogjamAgent::ComputeRenderTimes

# Define exception, but don't do anything about it. Sneaky!
module ActionDispatch
  module RemoteIp
    class IpSpoofAttackError < StandardError; end
  end
end

# Add GC time bandit
TimeBandits.reset
TimeBandits.add TimeBandits::TimeConsumers::GarbageCollection.instance if GC.respond_to? :enable_stats
