module LogjamAgent
  class ZMQForwarder

    attr_reader :app, :env

    def initialize(app, env, opts = {})
      @app = app
      @env = env
      @config = default_options(app, env).merge!(opts)
      @exchange = @config[:exchange]
      @zmq_host = @config[:host]
      # TODO: we should probably try to shut down cleanly
      # at_exit { shutdown }
    end

    def default_options(app, env)
      {
        :host         => "localhost",
        :exchange     => "request-stream-#{app}-#{env}",
        :routing_key  => "logs.#{app}.#{env}"
      }
    end

    def context
      @context ||=
        begin
          require 'zmq'
          ZMQ::Context.new(1)
        end
    end

    def socket
      @socket ||=
        begin
          socket = context.socket(ZMQ::PUSH)
          socket.setsockopt(ZMQ::LINGER, 100)
          socket.setsockopt(ZMQ::HWM, 10)
          socket.connect("tcp://#{@zmq_host}:12345")
          socket
        end
    end

    def reset
      return unless @socket
      puts "closing socket"
      @socket.close
      @socket = nil
    end

    def shutdown
      reset
      if @context
        puts "closing context"
        @context.close
      end
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
      if socket.send(@exchange, ZMQ::SNDMORE|ZMQ::NOBLOCK)
        socket.send(key, ZMQ::SNDMORE|ZMQ::NOBLOCK)
        socket.send(data, ZMQ::NOBLOCK)
      else
        raise "failed to send zeromq message"
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
