module LogjamAgent
  class ZMQForwarder
    attr_reader :app, :env

    include Util

    SEQUENCE_START = 0

    def initialize(*args)
      opts = args.extract_options!
      @app = args[0] || LogjamAgent.application_name
      @env = args[1] || LogjamAgent.environment_name
      @app_env = "#{@app}-#{@env}"
      @config = default_options.merge!(opts)
      @config[:host] = "localhost" if @config[:host].blank?
      @sequence = SEQUENCE_START
    end

    def connection_specs
      @connection_specs ||= @config[:host].split(',').map do |host|
        augment_connection_spec(host, @config[:port])
      end
    end

    def default_options
      {
        :port       => 9604,
        :linger     => 1000,
        :snd_hwm    =>  100,
        :rcv_hwm    =>  100,
        :rcv_timeo  => 5000,
        :snd_timeo  => 5000
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
      @socket = self.class.context.socket(ZMQ::DEALER)
      at_exit { reset }
      @socket.setsockopt(ZMQ::LINGER, @config[:linger])
      @socket.setsockopt(ZMQ::SNDHWM, @config[:snd_hwm])
      @socket.setsockopt(ZMQ::RCVHWM, @config[:rcv_hwm])
      @socket.setsockopt(ZMQ::RCVTIMEO, @config[:rcv_timeo])
      @socket.setsockopt(ZMQ::SNDTIMEO, @config[:snd_timeo])
      connection_specs.each do |spec|
        @socket.connect(spec)
      end
      @socket
    end

    def reset
      if @socket
        @socket.close
        @socket = nil
      end
    end

    def forward(data, options={})
      app_env = options[:app_env] || @app_env
      key = options[:routing_key] || "logs.#{app_env.sub('-','.')}"
      if engine = options[:engine]
        key += ".#{engine}"
      end
      msg = LogjamAgent.encode_payload(data)
      if options[:sync]
        send_receive(app_env, key, msg)
      else
        publish(app_env, key, msg)
      end
    rescue => error
      reraise_expectation_errors!
      raise ForwardingError.new(error.message)
    end

    def publish(app_env, key, data)
      info = pack_info(@sequence = next_fixnum(@sequence))
      parts = [app_env, key, data, info]
      if socket.send_strings(parts, ZMQ::DONTWAIT) < 0
        raise "ZMQ error on publishing: #{ZMQ::Util.error_string}"
      end
    end

    private

    def log_warning(message)
      LogjamAgent.error_handler.call ForwardingWarning.new(message)
    end

    VALID_RESPONSE_CODES = [200,202]

    def send_receive(app_env, key, data)
      info = pack_info(@sequence = next_fixnum(@sequence))
      request_parts = ["", app_env, key, data, info]
      answer_parts = []
      if socket.send_strings(request_parts) < 0
        log_warning "ZMQ error on sending: #{ZMQ::Util.error_string}"
        reset
        return
      end
      if socket.recv_strings(answer_parts) < 0
        log_warning "ZMQ error on receiving: #{ZMQ::Util.error_string}"
        reset
        return
      end
      if answer_parts.first != "" || !VALID_RESPONSE_CODES.include?(answer_parts.second.to_s.to_i)
        log_warning "unexpected answer from logjam broker: #{answer_parts.inspect}"
      end
    end

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
