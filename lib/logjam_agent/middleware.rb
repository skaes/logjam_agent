module LogjamAgent
  class Middleware
    def initialize(app, options={})
      @app = app
      @options = options
    end

    def call(env)
      start_request(env)
      @app.call(env)
    ensure
      finish_request(env)
    end

    private

    def start_request(env)
      Rails.logger.start_request(env["logjam_agent.application_name"]||LogjamAgent.application_name, Rails.env)
    end

    def finish_request(env)
      Rails.logger.finish_request(env["time_bandits.metrics"])
    end
  end
end
