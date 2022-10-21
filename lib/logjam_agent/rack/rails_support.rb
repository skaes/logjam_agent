# patch the actioncontroller logsubscriber to set the action on the logjam logger as soon as it starts processing the request
require 'action_controller/metal/instrumentation'
require 'action_controller/log_subscriber'

module ActionController #:nodoc:

  class LogSubscriber
    def start_processing(event)
      payload = event.payload
      params  = payload[:params].except(*INTERNAL_PARAMS)
      format  = payload[:format]
      format  = format.to_s.upcase if format.is_a?(Symbol)

      controller = payload[:controller]
      action = payload[:action]
      full_name = "#{controller}##{action}"
      action_name = LogjamAgent.action_name_proc.call(full_name)

      request = LogjamAgent.request
      request.fields[:action] = action_name

      request.log_info[:action] = action
      request.log_info[:controller] = controller
      request.log_info[:format] = format
      # request.log_info[:params] = params

      LogjamAgent.logjam_only do
        info "Processing by #{full_name} as #{format}"
        info "  Parameters: #{params.inspect}" unless params.empty?
      end
    end
  end

end
