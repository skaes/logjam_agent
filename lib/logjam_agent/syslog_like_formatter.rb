require 'logger'

module LogjamAgent
  class SyslogLikeFormatter
    def initialize
      @hostname = LogjamAgent.hostname
      @app_name = "rails"
      @attributes = []
      @newline = ActiveSupport::VERSION::STRING < "4.0" ? "" : "\n"
    end

    attr_accessor :attributes

    SEV_LABEL = Logger::SEV_LABEL.map{|sev| "%-5s" % sev}

    def format_severity(severity)
      if severity.is_a?(String)
        "%-5s" % severity
      else
        SEV_LABEL[severity] || 'ALIEN'
      end
    end

    def format_time(timestamp)
      timestamp.strftime("%b %d %H:%M:%S.#{"%06d" % timestamp.usec}")
    end

    def format_message(msg)
      msg.strip
    end

    def call(severity, timestamp, progname, msg)
      "#{format_severity(severity)} #{format_time(timestamp)}#{render_attributes}#{format_host_info(progname)}: #{format_message(msg)}#{@newline}"
    end

    if Rails.env.development?
      def format_host_info(proganme); ""; end
    else
      def format_host_info(progname)
       " #{@hostname} #{progname||@app_name}[#{$$}]"
      end
    end

    def render_attributes
      @attributes.map{|key, value| " #{key}[#{value}]"}.join
    end

    def set_attribute(name, value)
      if attribute = @attributes.detect{|n,v| n == name}
        attribute[1] = value
      else
        @attributes << [name, value]
      end
    end
  end
end
