require 'active_support/buffered_logger'
require 'active_support/core_ext/logger'
require 'fileutils'

module LogjamAgent
  class BufferedLogger < ActiveSupport::BufferedLogger

    attr_accessor :formatter

    def initialize(*args)
      super(*args)
      # stupid bug in the buffered logger code (Rails::VERSION::STRING < "3.2")
      @log.write "\n" if respond_to?(:buffer)
      @formatter = lambda{|_, _, _, message| message}
    end

    def request
      Thread.current[:logjam_request]
    end

    def request=(request)
      Thread.current[:logjam_request] = request
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
      request = self.request || Thread.main[:logjam_request]
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
      else # @log is a logger
        @log << "#{formatted_message}\n"
      end
      request.add_line(severity, time, message) if request
      message
    end

    def logdev=(log_device)
      raise "cannot connect logger to new log device" unless log_device.respond_to?(:write)
      if respond_to?(:buffer)
        @log = log_device
      else
        @log.instance_eval do
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
      msg = "#{exception.class} (#{exception.message})"
      if backtrace = exception.backtrace
        backtrace = Rails.backtrace_cleaner.clean(backtrace, :all) if defined?(Rails)
        msg << ":\n  #{backtrace.join("\n  ")}"
      else
        msg
      end
    end
  end
end
