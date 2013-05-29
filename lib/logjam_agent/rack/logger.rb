module LogjamAgent

  class CallerTimeoutExceeded < StandardError; end

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

        Thread.current.thread_variable_set(:time_bandits_completed_info, nil)

        request = ActionDispatch::Request.new(env)

        path = request.filtered_path

        logjam_fields = Rails.logger.request.fields
        logjam_fields.merge!(:started_at => start_time.iso8601, :ip => request.remote_ip, :host => @hostname)
        logjam_fields.merge!(extract_request_info(request))

        info "\n\nStarted #{request.request_method} \"#{path}\" for #{request.ip} at #{start_time.to_default_s}"
      end

      def after_dispatch(env, result, run_time_ms)
        status = result ? result.first : 500
        _, additions, view_time, _ = Thread.current.thread_variable_get(:time_bandits_completed_info)

        request_info = {:total_time => run_time_ms, :code => status, :view_time => view_time || 0.0}

        if (allowed_time_ms = env['HTTP_X_LOGJAM_CALLER_TIMEOUT'].to_i) > 0 && (run_time_ms > allowed_time_ms)
          warn LogjamAgent::CallerTimeoutExceeded.new("exceeded allowed time by #{(run_time_ms.to_i - allowed_time_ms)} ms")
        end

        message = "Completed #{status} #{::Rack::Utils::HTTP_STATUS_CODES[status]} in %.1fms" % run_time_ms
        message << " (#{additions.join(' | ')})" unless additions.blank?
        info message

        ActiveSupport::LogSubscriber.flush_all!

        Rails.logger.request.fields.merge!(request_info)

        env["time_bandits.metrics"] = TimeBandits.metrics
      end

      def extract_request_info(request)
        request_info = {}
        result = { :request_info => request_info }

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

        result
      rescue Exception
        Rails.logger.error($!)
        result
      end

      HIDDEN_VARIABLES = /\A([a-z]|SERVER|PATH|GATEWAY|REQUEST|SCRIPT|REMOTE|QUERY|PASSENGER|DOCUMENT|SCGI|UNION_STATION|ORIGINAL_FULLPATH|RAW_POST_DATA)/o

      TRANSLATED_VARIABLES = /\A(HTTP|CONTENT_LENGTH|CONTENT_TYPE)/

      TRANSLATED_KEYS = Hash.new do |h,k|
        h[k] = k.sub(/\AHTTP_/,'').split('_').map(&:capitalize).join('-') if k =~ TRANSLATED_VARIABLES
      end

      REFERER = 'HTTP_REFERER'
      CONTENT_LENGTH = 'CONTENT_LENGTH'

      KV_RE   = '[^&;=]+'
      PAIR_RE = %r{(#{KV_RE})=(#{KV_RE})}

      def extract_headers(request, filter)
        headers = request.env.reject{|k,v| k =~ HIDDEN_VARIABLES }
        headers.delete(CONTENT_LENGTH) if request.content_length == 0
        headers = filter.filter(headers)

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

# patch the actioncontroller logsubscriber to set the action on the logjam logger as soon as it starts processing the request
require 'action_controller/metal/instrumentation'
require 'action_controller/log_subscriber'

module ActionController #:nodoc:

  class LogSubscriber
    if Rails::VERSION::STRING =~ /^3.0/
      def start_processing(event)
        payload = event.payload
        params  = payload[:params].except(*INTERNAL_PARAMS)

        controller = payload[:controller]
        action = payload[:action]
        full_name = "#{controller}##{action}"
        action_name = LogjamAgent.action_name_proc.call(full_name)

        # puts "setting logjam action to #{action_name}"
        Rails.logger.request.fields[:action] = action_name

        info "  Processing by #{full_name} as #{payload[:formats].first.to_s.upcase}"
        info "  Parameters: #{params.inspect}" unless params.empty?
      end

    elsif Rails::VERSION::STRING =~ /^3.1/

      def start_processing(event)
        payload = event.payload
        params  = payload[:params].except(*INTERNAL_PARAMS)
        format  = payload[:format]
        format  = format.to_s.upcase if format.is_a?(Symbol)

        controller = payload[:controller]
        action = payload[:action]
        full_name = "#{controller}##{action}"
        action_name = LogjamAgent.action_name_proc.call(full_name)

        # puts "setting logjam action to #{action_name}"
        Rails.logger.request.fields[:action] = action_name

        info "  Processing by #{full_name} as #{format}"
        info "  Parameters: #{params.inspect}" unless params.empty?
      end

    elsif Rails::VERSION::STRING =~ /^3.2/

      def start_processing(event)
        payload = event.payload
        params  = payload[:params].except(*INTERNAL_PARAMS)
        format  = payload[:format]
        format  = format.to_s.upcase if format.is_a?(Symbol)

        controller = payload[:controller]
        action = payload[:action]
        full_name = "#{controller}##{action}"
        action_name = LogjamAgent.action_name_proc.call(full_name)

        # puts "setting logjam action to #{action_name}"
        Rails.logger.request.fields[:action] = action_name

        info "Processing by #{full_name} as #{format}"
        info "  Parameters: #{params.inspect}" unless params.empty?
      end

    else
      raise "loggjam_agent ActionController monkey patch is not compatible with your Rails version"
    end
  end

end
