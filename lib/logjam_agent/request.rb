require "json"
require "socket"

module LogjamAgent
  class Request
    attr_reader :fields

    @@hostname = Socket.gethostname.split('.').first

    def initialize(app, env, logger, initial_fields)
      @logger = logger
      @forwarder = Forwarders.get(app, env)
      @lines = []
      @fields = initial_fields.merge(:host => @@hostname, :process_id => Process.pid, :lines => @lines)
    end

    def add_line(severity, timestamp, message)
      @lines << [severity, format_time(timestamp), message.strip]
    end

    def add_exception(exception)
      ((@fields[:exceptions] ||= []) << exception.class.to_s).uniq!
    end

    def forward
      engine = @fields.delete(:engine)
      @forwarder.forward(@fields.to_json, engine)
    rescue Exception => e
      handle_forwarding_error(e)
    end

    private

    def format_time(t)
      # iso time with microseconds
      t.strftime("%Y-%m-%dT%H:%M:%S.#{"%06d" % t.usec}")
    end

    def handle_forwarding_error(exception)
      @logger.error exception.to_s
      LogjamAgent.error_handler.call(exception)
    rescue Exception
      # swallow all exceptions
    end

  end
end
