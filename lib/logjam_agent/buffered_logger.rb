require 'fileutils'

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

module LogjamAgent
  class BufferedLogger < ActiveSupport::Logger

    # for backwards compatibility. needs to go away.
    include LogjamAgent::RequestHandling

    def initialize(*args)
      super(*args)
      # make sure we always have a formatter
      self.formatter = Logger::Formatter.new
    end

    def formatter=(formatter)
      super
      @formatter.extend LoggingAttributes
    end

    def add(severity, message = nil, progname = nil, &block)
      return if level > severity
      message = progname if message.nil?
      progname = nil
      message ||= block.call || '' if block
      request = LogjamAgent.request
      if message.is_a?(Exception)
        request.add_exception(message.class.to_s, severity) if request
        message = format_exception(message)
      else
        message = message.to_s
        if request && severity >= Logger::ERROR && (e = detect_logged_exception(message))
          request.add_exception(e)
        end
      end
      log_to_log_device = LogjamAgent.log_to_log_device?(severity, message)
      attributes = formatter.render_attributes
      message = "[#{attributes}] #{message}" if attributes
      time = Time.now
      if log_to_log_device && !SelectiveLogging.logjam_only?
        formatted_message = formatter.call(format_severity(severity), time, progname, message)
        @logdev.write(formatted_message) if @logdev
      end
      request.add_line(severity, time, message) if request && !SelectiveLogging.logdevice_only?
      message
    end

    def logdev=(log_device)
      raise "cannot connect logger to new log device" unless log_device.respond_to?(:write)
      @logdev = log_device
    end

    private

    SEV_LABEL_CACHE = SEV_LABEL.map{|sev| "%-5s" % sev}

    def format_severity(severity)
      if severity.is_a?(String)
        "%-5s" % severity
      else
        SEV_LABEL_CACHE[severity] || 'ALIEN'
      end
    end

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
