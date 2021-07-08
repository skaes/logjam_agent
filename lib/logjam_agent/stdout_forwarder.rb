module LogjamAgent
  class STDOUTForwarder
    attr_reader :app, :env

    include Util

    def initialize(*args)
      opts = args.extract_options!
      @app = args[0] || LogjamAgent.application_name
      @env = args[1] || LogjamAgent.environment_name
      @app_env = "#{@app}-#{@env}"
      @config = opts
    end

    def reset
      $stdout.flush
    end

    def forward(data, options={})
      app_env = options[:app_env] || @app_env
      key = options[:routing_key] || "logs.#{app_env.sub('-','.')}"
      if engine = options[:engine]
        key += ".#{engine}"
      end
      # Bypass compression settings for stdout.
      msg = LogjamAgent.json_encode_payload(data)
      $stdout.write("#{msg}\n")
    rescue => error
      reraise_expectation_errors!
      raise ForwardingError.new(error.message)
    end

    private

    def log_warning(message)
      LogjamAgent.error_handler.call ForwardingWarning.new(message)
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
