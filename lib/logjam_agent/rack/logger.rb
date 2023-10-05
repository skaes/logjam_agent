module LogjamAgent

  class CallerTimeoutExceeded < StandardError; end
  class NegativeWaitTime < StandardError; end

  module Rack
    class Logger < ActiveSupport::LogSubscriber
      def initialize(app, taggers = nil)
        @app = app
        @taggers = taggers || (defined?(Rails::Railtie) ? Rails.application.config.log_tags : []) || []
        @hostname = LogjamAgent.hostname
        @asset_prefix = Rails.application.config.assets.prefix rescue "---"
        @ignore_asset_requests = LogjamAgent.ignore_asset_requests
        @ignored_request_urls = LogjamAgent.ignored_request_urls
        @use_to_default_s = Gem::Version.new(Rails::VERSION::STRING) < Gem::Version.new("7.1.0")
      end

      def call(env)
        if env["logjam_agent.framework"] == :sinatra
          request = ::Sinatra::Request.new(env)
          env["rack.logger"] = logger
        else
          request = ActionDispatch::Request.new(env)
        end

        if logger.respond_to?(:tagged) && !@taggers.empty?
          logger.tagged(compute_tags(request)) { call_app(request, env) }
        else
          call_app(request, env)
        end
      end

      protected

      def call_app(request, env)
        start_time = Time.now
        start_clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        wait_time = 0.0
        if http_start_time = extract_http_start_time(env)
          wait_time = start_time - http_start_time
          if wait_time > 0
            start_time = http_start_time
          else
            wait_time = 0.0
          end
        end
        wait_time_ms =  wait_time * 1000
        before_dispatch(request, env, start_time, wait_time_ms)
        result = @app.call(env)
      rescue ActionDispatch::RemoteIp::IpSpoofAttackError
        result = [403, {}, ['Forbidden']]
      ensure
        end_clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        run_time_ms = (end_clock - start_clock + wait_time) * 1000
        after_dispatch(env, result, run_time_ms, wait_time_ms)
      end

      def extract_http_start_time(env)
        start_time_header = env['HTTP_X_STARTTIME']
        if start_time_header
          if start_time_header =~ /\At=(\d+)\z/
            # HTTP_X_STARTTIME is microseconds since the epoch (UTC)
            return Time.at($1.to_f / 1_000_000.0)
          elsif start_time_header =~ /\Ats=(\d+)(?:\.(\d+))?\z/
            # HTTP_X_STARTTIME is seconds since the epoch (UTC) with a milliseconds resolution
            return Time.at($1.to_f + $2.to_f / 1000)
          end
        end
        return nil
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

      def ignored_request_url?(path)
        @ignored_request_urls.any?{|url_pattern| path =~ url_pattern}
      rescue
        false
      end

      def before_dispatch(request, env, start_time, wait_time_ms)
        logger.formatter.reset_attributes if logger.formatter.respond_to?(:reset_attributes)
        TimeBandits.reset
        Thread.current.thread_variable_set(:time_bandits_completed_info, nil)

        path = request.filtered_path

        logjam_request = LogjamAgent.request
        logjam_request.ignore!(:asset) if ignored_asset_request?(path)
        logjam_request.ignore!(:url) if ignored_request_url?(path)

        logjam_request.log_info[:path] = path
        logjam_request.log_info[:method] = request.method

        logjam_request.start_time = start_time
        logjam_fields = logjam_request.fields
        logjam_fields[:wait_time] = wait_time_ms if wait_time_ms > 0.0
        spoofed = nil
        ip = nil
        begin
          ip = LogjamAgent.ip_obfuscator((env["action_dispatch.remote_ip"] || request.ip).to_s)
        rescue ActionDispatch::RemoteIp::IpSpoofAttackError => spoofed
          ip = "*** SPOOFED IP ***"
        end
        logjam_fields.merge!(:ip => ip, :host => @hostname)
        logjam_fields.merge!(extract_request_info(request))

        LogjamAgent.logjam_only do
          started_at_str = @use_to_default_s ? start_time.to_default_s : start_time.to_s
          info "Started #{request.request_method} \"#{path}\" for #{ip} at #{started_at_str}" unless logjam_request.ignored?(:asset)
        end
        if spoofed
          error spoofed
          raise spoofed
        end
      end

      def after_dispatch(env, result, run_time_ms, wait_time_ms)
        status = result ? result.first.to_i : 500
        if completed_info = Thread.current.thread_variable_get(:time_bandits_completed_info)
          _, additions, view_time, _ = completed_info
        end
        additions ||= []
        if env["logjam_agent.framework"] == :sinatra
          TimeBandits.consumed
          additions.concat TimeBandits.runtimes
        end
        logjam_request = LogjamAgent.request

        if (allowed_time_ms = env['HTTP_X_LOGJAM_CALLER_TIMEOUT'].to_i) > 0 && (run_time_ms > allowed_time_ms)
          warn LogjamAgent::CallerTimeoutExceeded.new("exceeded allowed time by #{(run_time_ms.to_i - allowed_time_ms)} ms")
        end

        if wait_time_ms < 0
          warn LogjamAgent::NegativeWaitTime.new("#{wait_time_ms} ms")
        end

        http_status = "#{status} #{::Rack::Utils::HTTP_STATUS_CODES[status]}"
        LogjamAgent.logjam_only do
          message = "Completed #{http_status} in %.1fms" % run_time_ms
          message << " (#{additions.join(' | ')})" unless additions.blank?
          info message unless logjam_request.ignored?(:asset)
        end
        if LogjamAgent.selective_logging_enabled
          LogjamAgent.logdevice_only do
            logjam_request.log_info[:status] = status
            logjam_request.log_info[:duration] = run_time_ms
            # logjam_request.log_info[:metrics] = TimeBandits.metrics.reject{|k,v| v.zero?}
            if LogjamAgent.log_format == :json
              info message: "Completed #{http_status}", **logjam_request.log_info
            else
              info "Completed: #{logjam_request.log_info.to_json}"
            end
          end
        end

        ActiveSupport::LogSubscriber.flush_all!
        request_info = { :total_time => run_time_ms, :code => status }
        request_info[:view_time] = view_time if view_time
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
        logger.error(e)
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

      include Obfuscation

      def extract_headers(request, filter)
        headers = request.env.reject{|k,v| k =~ HIDDEN_VARIABLES }
        headers.delete(CONTENT_LENGTH) if request.content_length == 0
        headers = filter.filter(headers)

        if referer = headers[REFERER]
          headers[REFERER] = filter_pairs(referer, filter)
        end

        if (cookie = headers[COOKIE]) && obfuscated_cookies.present?
          headers[COOKIE] = obfuscate_cookie(cookie, cookie_obfuscator)
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

if defined?(Rails::Railtie)
  require_relative "rails_support"
end
