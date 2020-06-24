$:.unshift File.expand_path('../../lib', __FILE__)
require "logjam_agent"

require 'sinatra/base'
require 'sinatra/custom_logger'
require 'logjam_agent/middleware'
require 'logjam_agent/rack/logger'
require 'time_bandits'

class SinatraTestApp < Sinatra::Base
  helpers Sinatra::CustomLogger

  helpers do
    def action_name(action_name)
      LogjamAgent.request.fields[:action] = action_name
    end
  end

  configure :development, :test, :production do
    enable :logging
    logger = LogjamAgent::BufferedLogger.new(STDOUT)
    logger.formatter = LogjamAgent::SyslogLikeFormatter.new
    logger = ActiveSupport::TaggedLogging.new(logger)
    LogjamAgent.logger = logger
    LogjamAgent.log_device_log_level = logger.level
    ActiveSupport::LogSubscriber.logger = logger
    set :logger, logger
  end

  LogjamAgent.application_name = "myapp"
  LogjamAgent.environment_name = "test"
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

  use LogjamAgent::Middleware
  use LogjamAgent::Rack::Logger

  LogjamAgent.parameter_filters << :password

  get '/index' do
    action_name "Simple#index"
    logger.info 'Hello World!'
    'Hello World!'
  end

  run! if __FILE__ == $0
end
