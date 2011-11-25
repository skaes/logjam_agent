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
      headers["X-Logjam-Caller-Id"] = request.fields[:caller_id]
      finish_request(env)
    end

    private

    def start_request(env)
      app_name  = env["logjam_agent.application_name"] || LogjamAgent.application_name
      env_name  = env["logjam_agent.environment_name"] || LogjamAgent.environment_name
      caller_id = env["HTTP_X_LOGJAM_CALLER_ID"] || ""
      Rails.logger.start_request(app_name, env_name, :caller_id => caller_id)
    end

    def finish_request(env)
      Rails.logger.finish_request(env["time_bandits.metrics"])
    end
  end
end
