ActionController::Dispatcher.middleware.insert_before(ActionController::Failsafe, LogjamAgent::Middleware)
