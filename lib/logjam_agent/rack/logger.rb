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

        Rails.logger.request.fields.merge!(:started_at => start_time.iso8601, :ip => request.ip, :host => @hostname)

        info "\n\nStarted #{request.request_method} \"#{path}\" for #{request.ip} at #{start_time.to_default_s}"
      end

      def after_dispatch(env, result, run_time_ms)
        status = result ? result.first : 500
        duration, additions, view_time, action = Thread.current[:time_bandits_completed_info]

        basic_request_info = {:total_time => run_time_ms, :code => status, :action => action, :view_time => view_time || 0.0}

        message = "Completed #{status} #{::Rack::Utils::HTTP_STATUS_CODES[status]} in %.1fms" % run_time_ms
        message << " (#{additions.join(' | ')})" unless additions.blank?
        info message

        ActiveSupport::LogSubscriber.flush_all!

        Rails.logger.request.fields.merge!(basic_request_info)

        env["time_bandits.metrics"] = TimeBandits.metrics
      end

    end
  end
end
