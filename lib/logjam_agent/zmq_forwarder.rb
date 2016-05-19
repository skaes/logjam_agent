module LogjamAgent
  class ZMQForwarder
    attr_reader :app, :env, :connection_specs

    include Util

    def initialize(*args)
      opts = args.extract_options!
      @app = args[0] || LogjamAgent.application_name
      @env = args[1] || LogjamAgent.environment_name
      @app_env = "#{@app}-#{@env}"
      @config = default_options.merge!(opts)
      @config[:host] = "localhost" if @config[:host].blank?
      @connection_specs = @config[:host].split(',').map do |host|
        augment_connection_spec(host, @config[:port])
      end
      @sequence = 0
    end

    def default_options
      {
        :port         => 9605,
        :linger       => 1000,
        :snd_hwm      => 100,
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
      return @socket if @socket
      @socket = self.class.context.socket(ZMQ::PUSH)
      at_exit { reset }
      @socket.setsockopt(ZMQ::LINGER, @config[:linger])
      @socket.setsockopt(ZMQ::SNDHWM, @config[:snd_hwm])
      @connection_specs.each do |spec|
        @socket.connect(spec)
      end
      @socket
    end

    def reset
      return unless @socket
      @socket.close
      @socket = nil
    end

    def forward(data, options={})
      app_env = options[:app_env] || @app_env
      key = options[:routing_key] || "logs.#{app_env.sub('-','.')}"
      if engine = options[:engine]
        key += ".#{engine}"
      end
      msg = LogjamAgent.encode_payload(data)
      publish(app_env, key, msg)
    rescue => error
      reraise_expectation_errors!
      raise ForwardingError.new(error.message)
    end

    def publish(app_env, key, data)
      info = pack_info(@sequence = next_fixnum(@sequence))
      parts = [app_env, key, data, info]
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
