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

    elsif Rails::VERSION::STRING =~ /\A(3\.2|4|5|6)/

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
