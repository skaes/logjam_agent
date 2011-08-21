require "json"
require "socket"

module LogjamAgent
  class Request
    attr_reader :fields

    @@hostname = Socket.gethostname.split('.').first

    def initialize(app, env)
      @forwarder = Forwarders.get(app, env)
      @lines = []
      @fields = {
        :host => @@hostname,
        :pid => Process.pid,
        :lines => @lines
      }
    end

    def add_message(severity, timestamp, message)
      @lines << [severity, format_time(timestamp), message]
    end

    def forward
      @forwarder.send(@fields.to_json)
    end

    private
    def format_time(t)
      # iso time with microseconds
      t.strftime("%Y-%m-%dT%H:%M:%S.#{t.usec}")
    end

  end
end
