module LogjamAgent
  class AMQPForwarder

    RETRY_AFTER = 10.seconds

    attr_reader :app, :env

    include LogjamAgent::Util

    def initialize(*args)
      opts = args.extract_options!
      @app = args[0] || LogjamAgent.application_name
      @env = args[1] || LogjamAgent.environment_name
      @app_env = "#{@app}-#{@env}"
      @config = default_options.merge!(opts)
      @exchanges = {}
      @bunny = nil
      @sequence = 0
      ensure_bunny_gem_is_available
    end

    def default_options
      {
        :host                 => "localhost",
        :exchange_durable     => true,
        :exchange_auto_delete => false,
      }
    end

    # TODO: mutex!
    def forward(msg, options = {})
      return if paused? || LogjamAgent.disabled
      begin
        app_env = options[:app_env] || @app_env
        key = options[:routing_key] || "logs.#{app_env.sub('-','.')}"
        if engine = options[:engine]
          key += ".#{engine}"
        end
        info = pack_info(@sequence = next_fixnum(@sequence))
        exchange(app_env).publish(msg, :key => key, :persistent => false, :headers => {:info => info})
      rescue => error
        reraise_expectation_errors!
        pause(error)
      end
    end

    def reset(exception=nil)
      return unless @bunny
      begin
        if exception
          @bunny.__send__(:close_socket)
        else
          @bunny.stop
        end
      rescue
        # if bunny throws an exception here, its not usable anymore anyway
      ensure
        @exchanges = {}
        @bunny = nil
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

    def pause(exception)
      @paused = Time.now
      reset(exception)
      raise ForwardingError.new("Could not log to AMQP exchange (#{exception.message})")
    end

    def paused?
      @paused && @paused > RETRY_AFTER.ago
    end

    def exchange(app_env)
      @exchanges[app_env] ||=
        begin
          bunny.start unless bunny.connected?
          bunny.exchange("request-stream-#{app_env}",
                         :durable => @config[:exchange_durable],
                         :auto_delete => @config[:exchange_auto_delete],
                         :type => :topic)
        end
    end

    #TODO: verify socket_timout for ruby 1.9
    def bunny
      @bunny ||= Bunny.new(:host => @config[:host], :socket_timeout => 1.0)
    end

    def ensure_bunny_gem_is_available
      require "bunny" unless defined?(Bunny)
    end
  end
end
