module LogjamAgent
  module RequestHandling
    extend self

    def request
      Thread.current.thread_variable_get(:logjam_request)
    end

    def request=(request)
      Thread.current.thread_variable_set(:logjam_request, request)
    end

    def start_request(*args)
      initial_fields = args.extract_options!
      app = args[0] || LogjamAgent.application_name
      env = args[1] || LogjamAgent.environment_name
      self.request = Request.new(app, env, initial_fields)
    end

    def finish_request(additional_fields = {})
      if request = self.request
        request.fields.merge!(additional_fields)
        self.request = nil
        request.forward
      end
    end
  end
end
