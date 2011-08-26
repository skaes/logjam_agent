require "json"
require "socket"

module LogjamAgent
  class Request
    attr_reader :fields

    @@hostname = Socket.gethostname.split('.').first

    def initialize(app, env, logger)
      @logger = logger
      @forwarder = Forwarders.get(app, env)
      @lines = []
      @fields = {
        :host => @@hostname,
        :pid => Process.pid,
        :lines => @lines
      }
    end

    def add_line(severity, timestamp, message)
      @lines << [severity, format_time(timestamp), message]
    end

    def forward
      @forwarder.send(@fields.to_json)
    rescue Exception => e
      handle_forwarding_error(e)
    end

    private

    def format_time(t)
      # iso time with microseconds
      t.strftime("%Y-%m-%dT%H:%M:%S.#{t.usec}")
    end

    def handle_forwarding_error(exception)
      @logger.error exception.to_s
      begin
        LogjamAgent.error_handler.call(exception)
      rescue Exception
      end
    end
  end
end
