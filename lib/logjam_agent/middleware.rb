module LogjamAgent
  class Middleware
    def initialize(app, options={})
      @app = app
      @options = options
    end

    def call(env)
      request = start_request(env)
      result = @app.call(env)
      result[1] ||= {}
      result
    rescue Exception
      result = [500, {'Content-Type' => 'text/html'}, ["<html><body><h1>500 Internal Server Error</h1>"]]
    ensure
      headers = result[1]
      headers["X-Logjam-Request-Id"] = request.id
      # this cookie is intended for JS code, which can't read it from response headers.
      # it's superior to returning it with the html body, because that makes caching hard.
      if set_request_id_cookie?(request, env)
        ::Rack::Utils.set_cookie_header!(headers, "X-Logjam-Request-Id", {:value => request.id, :path => "/"})
      end
      unless (request_action = request.fields[:action]).blank?
        headers["X-Logjam-Request-Action"] = request_action
      end
      unless (caller_id = request.fields[:caller_id]).blank?
        headers["X-Logjam-Caller-Id"] = caller_id
      end
      finish_request(env)
    end

    private

    def start_request(env)
      app_name      = env["logjam_agent.application_name"] || LogjamAgent.application_name
      env_name      = env["logjam_agent.environment_name"] || LogjamAgent.environment_name
      caller_id     = env["HTTP_X_LOGJAM_CALLER_ID"] || ""
      caller_action = env["HTTP_X_LOGJAM_ACTION"] || ""
      LogjamAgent.start_request(app_name, env_name, :caller_id => caller_id, :caller_action => caller_action)
    end

    def finish_request(env)
      LogjamAgent.finish_request(env["time_bandits.metrics"])
    end

    def set_request_id_cookie?(request, env)
      !(request.ignored? || env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest")
    end
  end
end
