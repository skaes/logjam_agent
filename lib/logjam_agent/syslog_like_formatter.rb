require 'logger'

module LogjamAgent
  class SyslogLikeFormatter
    def initialize
      @hostname = LogjamAgent.hostname
      @app_name = "rails"
    end

    def attributes=(attributes)
      Thread.current.thread_variable_set(:__logjam_formatter_attributes__, attributes)
    end

    def attributes
      unless attributes = Thread.current.thread_variable_get(:__logjam_formatter_attributes__)
        attributes = Thread.current.thread_variable_set(:__logjam_formatter_attributes__, [])
      end
      attributes
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

    def render_attributes
      attributes.map{|key, value| " #{key}[#{value}]"}.join
    end

    def set_attribute(name, value)
      if attribute = attributes.detect{|n,v| n == name}
        attribute[1] = value
      else
        attributes << [name, value]
      end
    end

    def reset_attributes
      self.attributes = []
    end
  end
end
