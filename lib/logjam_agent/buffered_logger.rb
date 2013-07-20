require 'fileutils'

if ActiveSupport::VERSION::STRING < "4.0"
  require 'active_support/buffered_logger'
  require 'active_support/core_ext/logger'
else
  require 'active_support/logger'

  class LogjamAgent::ConsoleFormatter < Logger::Formatter
    # This method is invoked when a log event occurs
    def call(severity, timestamp, progname, msg)
      "[#{format_time(timestamp)}] #{String === msg ? msg : msg.inspect}\n"
    end

    def format_time(timestamp)
      timestamp.strftime("%H:%M:%S.#{"%06d" % timestamp.usec}")
    end
  end

  class ActiveSupport::Logger
    class << self
      alias_method :original_broadcast, :broadcast
      def broadcast(logger)
        logger.formatter = LogjamAgent::ConsoleFormatter.new
        logger.formatter.extend(ActiveSupport::TaggedLogging::Formatter)
        original_broadcast(logger)
      end
    end
  end
end

module LogjamAgent
  class BufferedLogger < ( ActiveSupport::VERSION::STRING < "4.0" ?
                           ActiveSupport::BufferedLogger : ActiveSupport::Logger )

    attr_accessor :formatter

    def initialize(*args)
      super(*args)
      # stupid bug in the buffered logger code (Rails::VERSION::STRING < "3.2")
      @log.write "\n" if @log && respond_to?(:buffer)
      @formatter = lambda{|_, _, _, message| message}
    end

    def request
      Thread.current.thread_variable_get(:logjam_request)
    end

    def request=(request)
      Thread.current.thread_variable_set(:logjam_request, request)
    end

    def start_request(app, env, initial_fields={})
      self.request = Request.new(app, env, self, initial_fields)
    end

    def finish_request(additional_fields={})
      if request = self.request
        request.fields.merge!(additional_fields)
        self.request = nil
        request.forward
      end
    end

    def add(severity, message = nil, progname = nil, &block)
      return if level > severity
      message = progname if message.nil?
      progname = nil # rails 3.2 bug when using tagged logging
      request = self.request || Thread.main.thread_variable_get(:logjam_request)
      if message.is_a?(Exception)
        request.add_exception(message.class.to_s) if request
        message = format_exception(message)
      else
        message = (message || (block && block.call) || '').to_s
        if request && severity >= Logger::ERROR && (e = detect_logged_exception(message))
          request.add_exception(e)
        end
      end
      time = Time.now
      formatted_message = formatter.call(severity, time, progname, message)
      if respond_to?(:buffer)
        buffer <<  formatted_message << "\n"
        auto_flush
      elsif @log # @log is a logger (or nil for rails 4)
        @log << "#{formatted_message}\n"
      elsif @logdev
        @logdev.write(formatted_message)
      end
      request.add_line(severity, time, message) if request
      message
    end

    def logdev=(log_device)
      raise "cannot connect logger to new log device" unless log_device.respond_to?(:write)
      if respond_to?(:buffer)
        @log = log_device
      else
        (@log||self).instance_eval do
          raise "cannot set log device" unless defined?(@logdev)
          @logdev = log_device
        end
      end
    end

    private

    def detect_logged_exception(message)
      (matcher = LogjamAgent.exception_matcher) && message[matcher]
    end

    def format_exception(exception)
      msg = "#{exception.class}(#{exception.message})"
      if backtrace = exception.backtrace
        backtrace = Rails.backtrace_cleaner.clean(backtrace, :all) if defined?(Rails)
        msg << ":\n  #{backtrace.join("\n  ")}"
      else
        msg
      end
    end
  end
end
