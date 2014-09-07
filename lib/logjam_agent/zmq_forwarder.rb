module LogjamAgent
  class ZMQForwarder
    attr_reader :app, :env

    include Util

    def initialize(*args)
      opts = args.extract_options!
      @app = args[0] || LogjamAgent.application_name
      @env = args[1] || LogjamAgent.environment_name
      @config = default_options(@app, @env).merge!(opts)
      @app_env = "#{@app}-#{@env}"
      @zmq_hosts = Array(@config[:host])
      @zmq_port = @config[:port]
      @sequence = 0
    end

    def default_options(app, env)
      {
        :host         => "localhost",
        :routing_key  => "logs.#{app}.#{env}",
        :port         => 12345
      }
    end

    @@mutex = Mutex.new
    @@zmq_context = nil

    def self.context
      @@mutex.synchronize do
        @@zmq_context ||=
          begin
            require 'ffi-rzmq'
            context = ZMQ::Context.new(1)
            at_exit { context.terminate }
            context
          end
      end
    end

    def socket
      @socket ||=
        begin
          socket = self.class.context.socket(ZMQ::PUSH)
          socket.setsockopt(ZMQ::LINGER, 100)
          socket.setsockopt(ZMQ::SNDHWM, 10)
          @zmq_hosts.each do |host|
            socket.connect("tcp://#{host}:#{@zmq_port}")
          end
          at_exit { reset }
          socket
        end
    end

    def reset
      return unless @socket
      # $stderr.puts "closing socket"
      @socket.close
      @socket = nil
    end

    def forward(msg, options={})
      return if LogjamAgent.disabled
      begin
        key = options[:routing_key] || @config[:routing_key]
        if engine = options[:engine]
          key += ".#{engine}"
        end
        publish(key, msg)
      rescue => error
        reraise_expectation_errors!
        raise ForwardingError.new(error.message)
      end
    end

    def publish(key, data)
      info = pack_info(@sequence = next_fixnum(@sequence))
      parts = [@app_env, key, data, info]
      if socket.send_strings(parts, ZMQ::DONTWAIT) < 0
        raise "ZMQ error: #{ZMQ::Util.error_string}"
      end
    end

    private

    if defined?(Mocha)
      def reraise_expectation_errors! #:nodoc:
        raise if $!.is_a?(Mocha::ExpectationError)
      end
    else
      def reraise_expectation_errors! #:nodoc:
        # noop
      end
    end

  end
end
