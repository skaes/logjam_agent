$:.unshift File.expand_path('../../lib', __FILE__)

require 'logjam_agent/sinatra'

class SinatraTestApp < Sinatra::Base
  register LogjamAgent::Sinatra

  use LogjamAgent::Sinatra::Middleware

  configure do
    set :root, File.expand_path('../..', __FILE__)
    set :environment, :test
    set :loglevel, :debug
    setup_logjam_logger

    LogjamAgent.application_name = "myapp"
    LogjamAgent.add_forwarder(:zmq, :host => "inproc://app")
    LogjamAgent.parameter_filters << :password
    LogjamAgent.ensure_ping_at_exit = false
  end

  before '/index' do
    action_name "Simple#index"
  end

  get '/index' do
    logger.info 'Hello World!'
    'Hello World!'
  end

  run! if __FILE__ == $0
end
