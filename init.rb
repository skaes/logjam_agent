ActionController::Dispatcher.middleware.insert_before(ActionController::Failsafe, LogjamAgent::Middleware)
LogjamAgent.application_name ||= "rails"
LogjamAgent.environment_name ||= Rails.env
