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
      logjam_message = format_message_for_logjam(message, request, severity)
      time = Time.now
      request.add_line(severity, time, logjam_message) if request && !SelectiveLogging.logdevice_only?
      log_to_log_device = LogjamAgent.log_to_log_device?(severity, logjam_message)
      log_to_log_device = false if request && request.ignored?
      if log_to_log_device && !SelectiveLogging.logjam_only?
        device_message = format_message_for_log_device(message)
        formatted_message = formatter.call(format_severity(severity), time, progname, device_message)
        @logdev.write(formatted_message) if @logdev
      end
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
        backtrace = Rails.backtrace_cleaner.clean(backtrace, :all) if defined?(Rails) && Rails.respond_to?(:backtrace_cleaner)
        msg << ":\n  #{backtrace.join("\n  ")}"
      else
        msg
      end
    end

    def format_message_for_log_device(message, format: LogjamAgent.log_format)
      case message
      when Exception
        if format == :json
          encode_log_message(message: message.message, error: format_exception(message))
        else
          prepend_attribute_tags(format_exception(message))
        end
      when Hash
        if format == :json
          encode_log_message(message)
        else
          prepend_attribute_tags(LogjamAgent.json_encode_payload(message))
        end
      else
        if format == :json
          encode_log_message(message: message.to_s)
        else
          prepend_attribute_tags(message)
        end
      end
    end

    def format_message_for_logjam(message, request, severity)
      case message
      when Exception
        request.add_exception(message.class.to_s, severity) if request
        message = format_exception(message)
      when Hash
        message = LogjamAgent.json_encode_payload(message)
      else
        if request && severity >= Logger::ERROR && (e = detect_logged_exception(message))
          request.add_exception(e)
        end
      end
      prepend_attribute_tags(message)
    end

    def prepend_attribute_tags(message)
      attributes = formatter.render_attributes
      message = "[#{attributes}] #{message}" if attributes
      message
    end

    def encode_log_message(message_hash)
      attrs = formatter.non_nil_attributes.to_h
      msg = attrs.merge(message_hash)
      LogjamAgent.json_encode_payload(msg)
    end
  end
end
