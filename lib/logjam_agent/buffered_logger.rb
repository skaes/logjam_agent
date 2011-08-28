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

    def start_request(app, env, initial_fields={})
      Thread.current[:logjam_request] = Request.new(app, env, self, initial_fields)
    end

    def finish_request(additional_fields={})
      # puts "finishing request"
      if request = self.request
        request.fields.merge!(additional_fields)
        Thread.current[:logjam_request] = nil
        request.forward
      end
    end

    def request
      Thread.current[:logjam_request]
    end

    def add(severity, message = nil, progname = nil, &block)
      return if @level > severity
      message = (message || (block && block.call) || '').to_s
      # If a newline is necessary then create a new message ending with a newline.
      # Ensures that the original message is not mutated.
      message = "#{message}\n" unless message[-1] == ?\n
      time = Time.now
      buffer << formatter.call(severity, time, progname, message)
      auto_flush
      if request = self.request
        # puts "adding line to request"
        request.add_line(severity, time, message[0..-2])
      end
      message
    end

    def logdev=(log_device)
      raise "cannot connect logger to new log device" unless log_device.respond_to?(:write)
      @log = log_device
    end
  end
end
