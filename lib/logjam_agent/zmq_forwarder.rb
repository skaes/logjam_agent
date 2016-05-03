module LogjamAgent
  class ZMQForwarder
    attr_reader :app, :env

    include Util

    def initialize(*args)
      opts = args.extract_options!
      @app = args[0] || LogjamAgent.application_name
      @env = args[1] || LogjamAgent.environment_name
      @app_env = "#{@app}-#{@env}"
      @config = default_options.merge!(opts)
      @connection_specs = Array(@config[:host]).map{|host| "tcp://#{host}:#{@config[:port]}"}
      @sequence = 0
    end

    def default_options
      {
        :host         => "localhost",
        :port         => 9605,
        :linger       => 100,
        :snd_hwm      => 100,
        :io_threads   => 1
      }
    end

    @@mutex = Mutex.new
    @@zmq_context = nil

    def self.context
      @@mutex.synchronize do
        @@zmq_context ||=
          begin
            require 'ffi-rzmq'
            context = ZMQ::Context.new(@config[:io_threads])
            at_exit { context.terminate }
            context
          end
      end
    end

    def socket
      @socket ||=
        begin
          socket = self.class.context.socket(ZMQ::PUSH)
          socket.setsockopt(ZMQ::LINGER, @config[:linger])
          socket.setsockopt(ZMQ::SNDHWM, @config[:snd_hwm])
          @connection_specs.each do |spec|
            socket.connect(spec)
          end
          at_exit { reset }
          socket
        end
    end

    def reset
      return unless @socket
      @socket.close
      @socket = nil
    end

    def forward(msg, options={})
      app_env = options[:app_env] || @app_env
      key = options[:routing_key] || "logs.#{app_env.sub('-','.')}"
      if engine = options[:engine]
        key += ".#{engine}"
      end
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
