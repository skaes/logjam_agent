$:.unshift File.expand_path('../../lib', __FILE__)

require 'logjam_agent/sinatra'

class SinatraTestApp < Sinatra::Base
  register Sinatra::Logjam

  configure do
    set :root, File.expand_path('../..', __FILE__)
    set :environment, :test
    set :loglevel, :debug
    setup_logjam_logger

    LogjamAgent.application_name = "myapp"
    LogjamAgent.add_forwarder(
      :zmq,
      :host => "localhost",
      :port => 9604,
      :linger     => 10,
      :snd_hwm    => 10,
      :rcv_hwm    => 10,
      :rcv_timeo  => 10,
      :snd_timeo  => 10
    )
    LogjamAgent.parameter_filters << :password
  end

  get '/index' do
    action_name "Simple#index"
    logger.info 'Hello World!'
    'Hello World!'
  end

  run! if __FILE__ == $0
end
