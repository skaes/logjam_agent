module LogjamAgent
  module Rack
    class Logger < ActiveSupport::LogSubscriber
      def initialize(app)
        @app = app
        @hostname = LogjamAgent.hostname
      end

      def call(env)
        start_time = Time.now
        before_dispatch(env, start_time)
        result = @app.call(env)
      ensure
        run_time = Time.now - start_time
        after_dispatch(env, result, run_time*1000)
      end

      protected

      def before_dispatch(env, start_time)
        TimeBandits.reset

        Thread.current[:time_bandits_completed_info] = nil

        request = ActionDispatch::Request.new(env)

        path = request.filtered_path

        logjam_fields = Rails.logger.request.fields
        logjam_fields.merge!(:started_at => start_time.iso8601, :ip => request.ip, :host => @hostname)
        logjam_fields.merge!(extract_request_info(request))

        info "\n\nStarted #{request.request_method} \"#{path}\" for #{request.ip} at #{start_time.to_default_s}"
      end

      def after_dispatch(env, result, run_time_ms)
        status = result ? result.first : 500
        duration, additions, view_time, action = Thread.current[:time_bandits_completed_info]

        request_info = {:total_time => run_time_ms, :code => status, :action => action, :view_time => view_time || 0.0}

        message = "Completed #{status} #{::Rack::Utils::HTTP_STATUS_CODES[status]} in %.1fms" % run_time_ms
        message << " (#{additions.join(' | ')})" unless additions.blank?
        info message

        ActiveSupport::LogSubscriber.flush_all!

        Rails.logger.request.fields.merge!(request_info)

        env["time_bandits.metrics"] = TimeBandits.metrics
      end

      HIDDEN_VARIABLES = /\A([a-z]|SERVER|PATH|GATEWAY|REQUEST|SCRIPT|REMOTE|QUERY|PASSENGER|DOCUMENT|SCGI|UNION_STATION)/o

      TRANSLATED_VARIABLES = /\A(HTTP|CONTENT_LENGTH)/

      TRANSLATED_KEYS = Hash.new do |h,k|
        h[k] = k.sub(/\AHTTP_/,'').split('_').map(&:capitalize).join('-') if k =~ TRANSLATED_VARIABLES
      end

      REFERER = 'HTTP_REFERER'
      CONTENT_LENGTH = 'CONTENT_LENGTH'

      KV_RE   = '[^&;=]+'
      PAIR_RE = %r{(#{KV_RE})=(#{KV_RE})}

      def extract_request_info(request)
        request_info = {}
        filter = request.send(:parameter_filter)

        request_info[:method] = request.method
        request_info[:url] = request.filtered_path
        request_info[:headers] = extract_headers(request, filter)

        unless request.query_string.empty?
          query_params = filter.filter(request.query_parameters)
          request_info[:query_parameters] = query_params unless query_params.empty?
        end

        unless request.content_length == 0
          body_params = filter.filter(request.request_parameters)
          request_info[:body_parameters] = body_params unless body_params.empty?
        end

        { :request_info => request_info }
      rescue Exception
        Rails.logger.error($!)
        {}
      end

      def extract_headers(request, filter)
        headers = request.filtered_env
        headers.reject!{|k,v| k =~ HIDDEN_VARIABLES }
        headers.delete(CONTENT_LENGTH) if request.content_length == 0

        if referer = headers[REFERER]
          headers[REFERER] = referer.gsub(PAIR_RE) do |_|
            filter.filter([[$1, $2]]).first.join("=")
          end
        end

        headers.keys.each do |k|
          if t = TRANSLATED_KEYS[k]
            headers[t] = headers.delete(k)
          end
        end

        headers
      end

    end
  end
end
