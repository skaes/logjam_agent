require 'active_support/buffered_logger'

module LogjamAgent
  # Inspired by the buffered logger idea by Ezra
  class BufferedLogger < ActiveSupport::BufferedLogger

    attr_accessor :formatter

    def initialize(*args)
      super
      self.formatter = lambda{|timestamp, severity, message, progname| messsage}
    end

    def start_request(app, env)
      Thread.current[:logjam_request] = Request.new(app, env)
    end

    def finish_request
      if request = self.request
        Thread.current[:logjam_request] = nil
        request.forward
      end
    end

    def request
      Thread.current[:logjam_request]
    end

    def add(severity, message = nil, progname = nil, &block)
      return if @level > severity
      message = (message || (block && block.call) || progname).to_s
      # If a newline is necessary then create a new message ending with a newline.
      # Ensures that the original message is not mutated.
      message = "#{message}\n" unless message[-1] == ?\n
      time = Time.now
      buffer << formatter.call(severity, message, progname, time)
      auto_flush
      if request = self.request
        request.add_line(severity, time, message)
      end
      message
    end

    def flush
      @guard.synchronize do
        buffer.each do |content|
          @log.write(content)
        end

        # Important to do this even if buffer was empty or else @buffer will
        # accumulate empty arrays for each request where nothing was logged.
        clear_buffer

        # send request to logjam
        finish_request
      end
    end

  end
end
