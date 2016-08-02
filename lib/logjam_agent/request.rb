begin
  require "oj"
rescue LoadError
  require "json"
end

module LogjamAgent
  class Request
    attr_reader :fields, :uuid, :start_time
    attr_accessor :log_device_ignored_lines

    def initialize(app, env, initial_fields)
      @app = app
      @env = env
      @forwarder = Forwarders.get(app, env)
      @lines = []
      @uuid = LogjamAgent.generate_uuid
      @fields = initial_fields.merge(:request_id => @uuid, :host => LogjamAgent.hostname,
                                     :process_id => Process.pid, :lines => @lines)
      unless (revision = LogjamAgent.application_revision).blank?
        @fields[:revision] = revision
      end
      if start_time = @fields.delete(:start_time)
        self.start_time = start_time
      end
      @mutex = Mutex.new
      @ignored = false
      @bytes_all_lines = 0
      @max_bytes_all_lines = LogjamAgent.max_bytes_all_lines
      @max_line_length = LogjamAgent.max_line_length
    end

    def start_time=(start_time)
      @start_time = start_time
      @fields[:started_at] = start_time.iso8601
      @fields[:started_ms] = start_time.tv_sec * 1000 + start_time.tv_usec / 1000
    end

    def ignore!
      @ignored = true
    end

    def ignored?
      @ignored
    end

    def id
      "#{@app}-#{@env}-#{@uuid}"
    end

    def action
      @fields[:action]
    end

    def caller_id
      @fields[:caller_id]
    end

    def caller_action
      @fields[:caller_action]
    end

    def add_line(severity, timestamp, message)
      return if @bytes_all_lines > @max_bytes_all_lines
      message = message.strip
      if message.size > @max_line_length && severity < Logger::ERROR
        message[(@max_line_length-21)..-1] = " ... [LINE TRUNCATED]"
      end
      @mutex.synchronize do
        if (@bytes_all_lines += message.bytesize) < @max_bytes_all_lines
          @lines << [severity, format_time(timestamp), message]
        else
          @lines << [severity, format_time(timestamp), "... [LINES DROPPED]"]
        end
      end
    end

    def add_exception(exception)
      @mutex.synchronize do
        ((@fields[:exceptions] ||= []) << exception).uniq!
      end
    end

    def forward
      return if @ignored || LogjamAgent.disabled
      engine = @fields.delete(:engine)
      sync = @fields.delete(:sync)
      @forwarder.forward(@fields, :engine => engine, :sync => sync)
    rescue Exception => e
      handle_forwarding_error(e)
    end

    private

    def format_time(t)
      # iso time with microseconds
      t.strftime("%Y-%m-%dT%H:%M:%S.#{"%06d" % t.usec}")
    end

    def handle_forwarding_error(exception)
      LogjamAgent.logger.error exception.to_s if LogjamAgent.logger
      LogjamAgent.error_handler.call(exception)
    rescue Exception
      # swallow all exceptions
    end

  end
end
