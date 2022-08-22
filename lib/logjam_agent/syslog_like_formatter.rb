module LogjamAgent
  class SyslogLikeFormatter
    def initialize
      @hostname = LogjamAgent.hostname
      @app_name = "rails"
    end

    def format_time(timestamp)
      timestamp.strftime("%b %d %H:%M:%S.#{"%06d" % timestamp.usec}")
    end

    def format_message(msg)
      msg.strip
    end

    def call(severity, timestamp, progname, msg)
      "#{severity} #{format_time(timestamp)}#{format_host_info(progname)}: #{format_message(msg)}\n"
    end

    if !defined?(Rails::Railtie) || Rails.env.development?
      def format_host_info(progname); ""; end
    else
      def format_host_info(progname)
       " #{@hostname} #{progname||@app_name}[#{$$}]"
      end
    end

  end
end
