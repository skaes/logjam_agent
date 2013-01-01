module LogjamAgent
  class ZMQForwarder
    attr_reader :app, :env

    def initialize(app, env, opts = {})
      @app = app
      @env = env
      @config = default_options(app, env).merge!(opts)
      @exchange = @config[:exchange]
      @zmq_hosts = Array(@config[:host])
      @zmq_port = @config[:port]
    end

    def default_options(app, env)
      {
        :host         => "localhost",
        :exchange     => "request-stream-#{app}-#{env}",
        :routing_key  => "logs.#{app}.#{env}",
        :port         => 12345
      }
    end

    @@mutex = Mutex.new
    @@zmq_context = nil

    def context
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
            socket.connect("tcp://#{host}:#{port}")
          end
          socket
        end
    end

    def reset
      return unless @socket
      puts "closing socket"
      @socket.close
      @socket = nil
    end

    def forward(msg, engine)
      return if LogjamAgent.disabled
      begin
        $stderr.puts msg
        key = @config[:routing_key]
        key += ".#{engine}" if engine
        publish(key, msg)
      rescue Exception => exception
        reraise_expectation_errors!
      end
    end

    def publish(key, data)
      parts = [@exchange, key, data]
      if socket.send_strings(parts, ZMQ::NonBlocking) < 0
        raise "failed to send zeromq message: #{ZMQ::Util.error_string}"
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
