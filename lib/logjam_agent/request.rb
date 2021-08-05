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
      @fields[:trace_id] ||= @uuid
      unless (revision = LogjamAgent.application_revision).blank?
        @fields[:revision] = revision
      end
      if ENV['CLUSTER']
        @fields[:cluster] = ENV['CLUSTER']
      end
      if ENV['DATACENTER']
        @fields[:datacenter] = ENV['DATACENTER']
      end
      if ENV['NAMESPACE']
        @fields[:namespace] = ENV['NAMESPACE']
      end
      if start_time = @fields.delete(:start_time)
        self.start_time = start_time
      end
      @mutex = Mutex.new
      @ignored = false
      @bytes_all_lines = 0
      @max_bytes_all_lines = LogjamAgent.max_bytes_all_lines
      @max_line_length = LogjamAgent.max_line_length
      @lines_dropped = false
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

    def trace_id
      @fields[:trace_id]
    end

    def add_line(severity, timestamp, message)
      @mutex.synchronize do
        if @bytes_all_lines > @max_bytes_all_lines
          unless @lines_dropped
            @lines << [severity, format_time(timestamp), "... [LINES DROPPED]"]
            @lines_dropped = true
          end
          return
        end
        message = message.strip
        line_too_long = message.size > @max_line_length
        if line_too_long && severity < Logger::ERROR
          message[(@max_line_length-21)..-1] = " ... [LINE TRUNCATED]"
        end
        if (@bytes_all_lines += message.bytesize) > @max_bytes_all_lines
          if line_too_long
            message[(@max_line_length-21)..-1] = " ... [LINE TRUNCATED]"
          end
        end
        @lines << [severity, format_time(timestamp), message]
      end
    end

    def add_exception(exception, severity = Logger::ERROR)
      @mutex.synchronize do
        if LogjamAgent.split_hard_and_soft_exceptions && severity < Logger::ERROR
          ((@fields[:soft_exceptions] ||= []) << exception).uniq!
        else
          ((@fields[:exceptions] ||= []) << exception).uniq!
        end
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
