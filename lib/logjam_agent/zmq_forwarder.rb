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
      @socket = nil
      @ping_ensured = false
      @socket_mutex = Mutex.new
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
        :snd_hwm    => 1000,
        :rcv_hwm    => 1000,
        :rcv_timeo  => 5000,
        :snd_timeo  => 5000
      }
    end

    @@context_mutex = Mutex.new
    @@zmq_context = nil

    def self.context
      @@context_mutex.synchronize do
        @@zmq_context ||=
          begin
            require 'ffi-rzmq'
            context = ZMQ::Context.new(1)
            at_exit { context.terminate }
            context
          end
      end
    end

    def reset
      @socket_mutex.synchronize do
        if @socket
          @socket.close
          @socket = nil
        end
      end
    end

    def ensure_ping_at_exit
      return if @ping_ensured
      at_exit { ping; reset }
      @ping_ensured = true
    end

    def forward(data, options={})
      app_env = options[:app_env] || @app_env
      key = options[:routing_key] || "logs.#{app_env.sub('-','.')}"
      if engine = options[:engine]
        key += ".#{engine}"
      end
      msg = LogjamAgent.encode_payload(data)
      @socket_mutex.synchronize do
        if options[:sync]
          send_receive(app_env, key, msg)
        else
          publish(app_env, key, msg)
        end
      end
    rescue => error
      reraise_expectation_errors!
      raise ForwardingError.new(error.message)
    end

    private

    # this method assumes the caller holds the socket mutex
    def socket
      return @socket if @socket
      @socket = self.class.context.socket(ZMQ::DEALER)
      raise "ZMQ error on socket creation: #{ZMQ::Util.error_string}" if @socket.nil?
      if LogjamAgent.ensure_ping_at_exit
        ensure_ping_at_exit
      else
        at_exit { reset }
      end
      @socket.setsockopt(ZMQ::LINGER, @config[:linger])
      @socket.setsockopt(ZMQ::SNDHWM, @config[:snd_hwm])
      @socket.setsockopt(ZMQ::RCVHWM, @config[:rcv_hwm])
      @socket.setsockopt(ZMQ::RCVTIMEO, @config[:rcv_timeo])
      @socket.setsockopt(ZMQ::SNDTIMEO, @config[:snd_timeo])
      spec = connection_specs.sort_by{rand}.first
      @socket.connect(spec)
      @socket
    end

    def publish(app_env, key, data)
      info = pack_info(@sequence = next_fixnum(@sequence))
      parts = [app_env, key, data, info]
      if socket.send_strings(parts, ZMQ::DONTWAIT) < 0
        error = ZMQ::Util.error_string
        reset if connection_specs.size > 1
        raise "ZMQ error on publishing: #{error}"
      end
    end

    def log_warning(message)
      LogjamAgent.error_handler.call ForwardingWarning.new(message)
    end

    VALID_RESPONSE_CODES = [200,202]

    def send_receive(app_env, key, data, compression_method = LogjamAgent.compression_method)
      info = pack_info(@sequence = next_fixnum(@sequence), compression_method)
      request_parts = ["", app_env, key, data, info]
      answer_parts = []
      if socket.send_strings(request_parts) < 0
        log_warning "ZMQ error on sending: #{ZMQ::Util.error_string}"
        reset
        return nil
      end
      if socket.recv_strings(answer_parts) < 0
        log_warning "ZMQ error on receiving: #{ZMQ::Util.error_string}"
        reset
        return nil
      end
      if answer_parts.first != "" || !VALID_RESPONSE_CODES.include?(answer_parts.second.to_s.to_i)
        log_warning "unexpected answer from logjam broker: #{answer_parts.inspect}"
      end
      answer_parts.second
    end

    def ping
      @socket_mutex.synchronize do
        if @socket && !send_receive("ping", @app_env, "{}", NO_COMPRESSION)
          log_warning "failed to receive pong"
        end
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
