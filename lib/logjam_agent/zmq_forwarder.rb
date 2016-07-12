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

    def push_connection_specs
      @push_connection_specs ||= @config[:host].split(',').map do |host|
        augment_connection_spec(host, @config[:port])
      end
    end

    def req_connection_specs
      @req_connection_specs ||= @config[:host].split(',').sort_by{rand}.map do |host|
        augment_connection_spec(host, @config[:req_port])
      end
    end

    def default_options
      {
        :req_port     => 9604,
        :port         => 9605,
        :linger       => 1000,
        :snd_hwm      => 100,
        :rcv_hwm      => 100,
        :rcv_timeo    => 5000,
        :snd_timeo    => 5000
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

    def push_socket
      return @push_socket if @push_socket
      @push_socket = self.class.context.socket(ZMQ::PUSH)
      at_exit { reset_push_socket }
      @push_socket.setsockopt(ZMQ::LINGER, @config[:linger])
      @push_socket.setsockopt(ZMQ::SNDHWM, @config[:snd_hwm])
      push_connection_specs.each do |spec|
        @push_socket.connect(spec)
      end
      @push_socket
    end
    alias socket push_socket

    def req_socket
      return @req_socket if @req_socket
      @req_socket = self.class.context.socket(ZMQ::REQ)
      at_exit { reset_req_socket }
      @req_socket.setsockopt(ZMQ::LINGER, @config[:linger])
      @req_socket.setsockopt(ZMQ::SNDHWM, @config[:snd_hwm])
      @req_socket.setsockopt(ZMQ::RCVHWM, @config[:rcv_hwm])
      @req_socket.setsockopt(ZMQ::RCVTIMEO, @config[:rcv_timeo])
      @req_socket.setsockopt(ZMQ::SNDTIMEO, @config[:snd_timeo])
      # @req_socket.setsockopt(ZMQ::REQ_CORRELATE, 1)
      # @req_socket.setsockopt(ZMQ::REQ_RELAXED, 1)
      req_connection_specs.each do |spec|
        @req_socket.connect(spec)
      end
      @req_socket
    end

    def reset_push_socket
      if @push_socket
        @push_socket.close
        @push_socket = nil
      end
    end

    def reset_req_socket
      if @req_socket
        @req_socket.close
        @req_socket = nil
      end
    end

    def reset
      reset_push_socket
      reset_req_socket
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
      if push_socket.send_strings(parts, ZMQ::DONTWAIT) < 0
        raise "ZMQ error on publishing: #{ZMQ::Util.error_string}"
      end
    end

    private

    def log_warning(message)
      LogjamAgent.error_handler.call ForwardingWarning.new(message)
    end

    def send_receive(app_env, key, data)
      # we don't need sequencing for synchronous calls
      info = pack_info(SEQUENCE_START)
      request_parts = [app_env, key, data, info]
      answer_parts = []
      # we retry a few times relying on zeromq lib to pick servers to talk to
      3.times do
        if req_socket.send_strings(request_parts) < 0
          log_warning "ZMQ error on sending: #{ZMQ::Util.error_string}"
          reset_req_socket
          next
        end
        if req_socket.recv_strings(answer_parts) < 0
          log_warning "ZMQ error on receiving: #{ZMQ::Util.error_string}"
          reset_req_socket
          next
        end
        return if answer_parts.first == "200 OK"
        answer_parts.clear
      end
      # if synchronous publishing fails, we just fall back to async
      log_warning "could not publish sychronously, falling back to async"
      publish(app_env, key, data)
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
