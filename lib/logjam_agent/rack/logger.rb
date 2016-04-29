module LogjamAgent

  class CallerTimeoutExceeded < StandardError; end
  class NegativeWaitTime < StandardError; end

  module Rack
    class Logger < ActiveSupport::LogSubscriber
      def initialize(app, taggers = nil)
        @app = app
        @taggers = taggers || Rails.application.config.log_tags || []
        @hostname = LogjamAgent.hostname
        @asset_prefix = Rails.application.config.assets.prefix rescue "---"
        @ignore_asset_requests = LogjamAgent.ignore_asset_requests
      end

      def call(env)
        request = ActionDispatch::Request.new(env)

        if logger.respond_to?(:tagged) && !@taggers.empty?
          logger.tagged(compute_tags(request)) { call_app(request, env) }
        else
          call_app(request, env)
        end
      end

      protected

      def call_app(request, env)
        start_time = Time.now
        start_time_header = env['HTTP_X_STARTTIME']
        if start_time_header && start_time_header =~ /\At=(\d+)\z/
          # HTTP_X_STARTTIME is microseconds since the epoch (UTC)
          http_start_time = Time.at($1.to_f / 1_000_000.0)
          if (wait_time_ms = (start_time - http_start_time) * 1000) > 0
            start_time = http_start_time
          end
        else
          wait_time_ms = 0.0
        end
        before_dispatch(request, env, start_time)
        result = @app.call(env)
      ensure
        run_time_ms = (Time.now - start_time) * 1000
        after_dispatch(env, result, run_time_ms, wait_time_ms)
      end

      def compute_tags(request)
        @taggers.collect do |tag|
          case tag
          when :uuid
            LogjamAgent.request.uuid
          when Proc
            tag.call(request)
          when Symbol
            request.send(tag)
          else
            tag
          end
        end
      end

      def ignored_asset_request?(path)
        @ignore_asset_requests && path.starts_with?(@asset_prefix)
      rescue
        false
      end

      def before_dispatch(request, env, start_time)
        logger.formatter.reset_attributes if logger.formatter.respond_to?(:reset_attributes)
        TimeBandits.reset
        Thread.current.thread_variable_set(:time_bandits_completed_info, nil)

        path = request.filtered_path

        logjam_request = LogjamAgent.request
        logjam_request.ignore! if ignored_asset_request?(path)

        logjam_request.start_time = start_time
        logjam_fields = logjam_request.fields
        ip = LogjamAgent.ip_obfuscator(env["action_dispatch.remote_ip"].to_s)
        logjam_fields.merge!(:ip => ip, :host => @hostname)
        logjam_fields.merge!(extract_request_info(request))

        info "Started #{request.request_method} \"#{path}\" for #{ip} at #{start_time.to_default_s}" unless logjam_request.ignored?
      end

      def after_dispatch(env, result, run_time_ms, wait_time_ms)
        status = result ? result.first.to_i : 500
        if completed_info = Thread.current.thread_variable_get(:time_bandits_completed_info)
          _, additions, view_time, _ = completed_info
        end
        logjam_request = LogjamAgent.request

        if (allowed_time_ms = env['HTTP_X_LOGJAM_CALLER_TIMEOUT'].to_i) > 0 && (run_time_ms > allowed_time_ms)
          warn LogjamAgent::CallerTimeoutExceeded.new("exceeded allowed time by #{(run_time_ms.to_i - allowed_time_ms)} ms")
        end

        if wait_time_ms < 0
          warn LogjamAgent::NegativeWaitTime.new("#{wait_time_ms} ms")
          wait_time_ms = 0.0
        end

        message = "Completed #{status} #{::Rack::Utils::HTTP_STATUS_CODES[status]} in %.1fms" % run_time_ms
        message << " (#{additions.join(' | ')})" unless additions.blank?
        info message unless logjam_request.ignored?

        ActiveSupport::LogSubscriber.flush_all!
        request_info = {
          :total_time => run_time_ms, :code => status, :view_time => view_time || 0.0, :wait_time => wait_time_ms
        }
        logjam_request.fields.merge!(request_info)

        env["time_bandits.metrics"] = TimeBandits.metrics
      end

      def extract_request_info(request)
        request_info = {}
        result = { :request_info => request_info }

        filter = request.send(:parameter_filter)

        request_info[:method] = request.method rescue "UnknownwMethod"
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
      rescue Exception => e
        Rails.logger.error(e)
        result
      end

      HIDDEN_VARIABLES = /\A([a-z]|SERVER|PATH|GATEWAY|REQUEST|SCRIPT|REMOTE|QUERY|PASSENGER|DOCUMENT|SCGI|UNION_STATION|ORIGINAL_|ROUTES_|RAW_POST_DATA|HTTP_AUTHORIZATION)/o

      TRANSLATED_VARIABLES = /\A(HTTP|CONTENT_LENGTH|CONTENT_TYPE)/

      TRANSLATED_KEYS = Hash.new do |h,k|
        h[k] = k.sub(/\AHTTP_/,'').split('_').map(&:capitalize).join('-') if k =~ TRANSLATED_VARIABLES
      end

      REFERER = 'HTTP_REFERER'
      CONTENT_LENGTH = 'CONTENT_LENGTH'
      COOKIE = 'HTTP_COOKIE'

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

        if (cookie = headers[COOKIE]) && LogjamAgent.obfuscated_cookies.present?
          headers[COOKIE] = cookie.gsub(PAIR_RE) do |_|
            LogjamAgent.cookie_obfuscator.filter([[$1, $2]]).first.join("=")
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
    if Rails::VERSION::STRING =~ /\A3\.0/
      def start_processing(event)
        payload = event.payload
        params  = payload[:params].except(*INTERNAL_PARAMS)

        controller = payload[:controller]
        action = payload[:action]
        full_name = "#{controller}##{action}"
        action_name = LogjamAgent.action_name_proc.call(full_name)

        LogjamAgent.request.fields[:action] = action_name

        info "  Processing by #{full_name} as #{payload[:formats].first.to_s.upcase}"
        info "  Parameters: #{params.inspect}" unless params.empty?
      end

    elsif Rails::VERSION::STRING =~ /\A3\.1/

      def start_processing(event)
        payload = event.payload
        params  = payload[:params].except(*INTERNAL_PARAMS)
        format  = payload[:format]
        format  = format.to_s.upcase if format.is_a?(Symbol)

        controller = payload[:controller]
        action = payload[:action]
        full_name = "#{controller}##{action}"
        action_name = LogjamAgent.action_name_proc.call(full_name)

        LogjamAgent.request.fields[:action] = action_name

        info "  Processing by #{full_name} as #{format}"
        info "  Parameters: #{params.inspect}" unless params.empty?
      end

    elsif Rails::VERSION::STRING =~ /\A(3\.2|4\.[012])/

      # Rails 4.1 uses method_added to automatically subscribe newly
      # added methods. Since start_processing is already defined, the
      # net effect is that start_processing gets called
      # twice. Therefore, we temporarily switch to protected mode and
      # change it back later to public.
      protected
      def start_processing(event)
        payload = event.payload
        params  = payload[:params].except(*INTERNAL_PARAMS)
        format  = payload[:format]
        format  = format.to_s.upcase if format.is_a?(Symbol)

        controller = payload[:controller]
        action = payload[:action]
        full_name = "#{controller}##{action}"
        action_name = LogjamAgent.action_name_proc.call(full_name)

        LogjamAgent.request.fields[:action] = action_name

        info "Processing by #{full_name} as #{format}"
        info "  Parameters: #{params.inspect}" unless params.empty?
      end
      public :start_processing

    else
      raise "logjam_agent ActionController monkey patch is not compatible with your Rails version"
    end
  end

end
