require 'active_support/buffered_logger'
require 'active_support/core_ext/logger'
require 'fileutils'

module LogjamAgent
  class BufferedLogger < ActiveSupport::BufferedLogger

    attr_accessor :formatter

    def initialize(*args)
      super(*args)
      # stupid bug in the buffered logger code
      @log.write "\n"
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
      return if @level > severity
      request = self.request
      if message.is_a?(Exception)
        request.add_exception(message.class.to_s) if request
        message = format_exception(message)
      else
        message = (message || (block && block.call) || '').to_s
        if request && severity >= Logger::ERROR && (ex = detect_logged_exception(message))
          request.add_exception(ex)
        end
      end
      time = Time.now
      buffer << formatter.call(severity, time, progname, message) << "\n"
      auto_flush
      request.add_line(severity, time, message) if request
      message
    end

    def logdev=(log_device)
      raise "cannot connect logger to new log device" unless log_device.respond_to?(:write)
      @log = log_device
    end

    @@exception_classes = []
    def self.auto_detect_exception(exception_class)
      # but ignore Exception classes created with Class.new (timeout.rb, my old friend)
      if (class_name = exception_class.to_s) =~ /^[\w:]+$/
        @@exception_classes << class_name
      end
    end

    @@exception_matcher = nil
    def self.reset_exception_matcher
      @@exception_matcher = Regexp.new(@@exception_classes.map{|e| Regexp.escape(e)}.join("|"))
    end

    def self.auto_detect_logged_exceptions
      determine_loaded_exception_classes
      Exception.class_eval <<-"EOS"
        def self.inherited(subclass)
          logger_class = ::LogjamAgent::BufferedLogger
          logger_class.auto_detect_exception(subclass)
          logger_class.reset_exception_matcher
        end
      EOS
    end

    private

    def detect_logged_exception(message)
      (matcher = @@exception_matcher) && message[matcher]
    end

    def self.determine_loaded_exception_classes
      ObjectSpace.each_object(Class) do |klass|
        auto_detect_exception(klass) if klass < Exception
      end
      reset_exception_matcher
    end

    def format_exception(exception)
      msg = "#{exception.class} : #{exception.message}"
      if backtrace = exception.backtrace
        backtrace = Rails.backtrace_cleaner.clean(backtrace, :all) if defined?(Rails)
        msg << "\n  #{backtrace.join("\n  ")}"
      else
        msg
      end
    end
  end
end
