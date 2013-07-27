require "socket"
require "uuid4r"
require "time_bandits"

module LogjamAgent
  module RequestHandling
    def request
      Thread.current.thread_variable_get(:logjam_request)
    end

    def request=(request)
      Thread.current.thread_variable_set(:logjam_request, request)
    end

    def start_request(app = LogjamAgent.application_name, env = LogjamAgent.environment_name, initial_fields = {})
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

require "logjam_agent/version"
require "logjam_agent/amqp_forwarder"
require "logjam_agent/zmq_forwarder"
require "logjam_agent/forwarders"
require "logjam_agent/request"
require "logjam_agent/buffered_logger"
require "logjam_agent/syslog_like_formatter"

if defined?(Rails) && Rails::VERSION::STRING >= "3.0"
  require "logjam_agent/railtie"
end

module LogjamAgent

  class ForwardingError < StandardError; end

  mattr_accessor :logger
  self.logger = nil

  mattr_accessor :error_handler
  self.error_handler = lambda { |exception| }

  mattr_accessor :application_name
  self.application_name = nil

  mattr_accessor :environment_name
  self.environment_name = nil

  mattr_accessor :action_name_proc
  self.action_name_proc = lambda{|name| name}

  def self.get_hostname
    n = Socket.gethostname
    if n.split('.').size > 1
      n
    else
      Socket.gethostbyname(n).first rescue n
    end
  end

  mattr_accessor :hostname
  self.hostname = self.get_hostname

  def self.disable!
    self.disabled = true
  end

  def self.enable!
    self.disabled = false
  end

  mattr_accessor :disabled
  self.disabled = false

  extend RequestHandling

  mattr_accessor :exception_classes
  self.exception_classes = []

  mattr_accessor :exception_matcher
  self.exception_matcher = nil

  def self.auto_detect_exception(exception_class)
    # ignore Exception classes created with Class.new (timeout.rb, my old friend)
    if (class_name = exception_class.to_s) =~ /^[\w:]+$/
      exception_classes << class_name unless exception_classes.include?(class_name)
    end
  end

  def self.reset_exception_matcher
    self.exception_matcher = Regexp.new(self.exception_classes.map{|e| Regexp.escape(e)}.join("|"))
  end

  def self.determine_loaded_exception_classes
    ObjectSpace.each_object(Class) do |klass|
      auto_detect_exception(klass) if klass < Exception
    end
    reset_exception_matcher
  end

  def self.auto_detect_logged_exceptions
    determine_loaded_exception_classes
    Exception.class_eval <<-"EOS"
      def self.inherited(subclass)
        ::LogjamAgent.auto_detect_exception(subclass)
        ::LogjamAgent.reset_exception_matcher
      end
    EOS
  end

  # setup json encoding
  begin
    require "oj"
    def self.encode_payload(data)
      Oj.dump(data, :mode => :compat)
    end
  rescue LoadError
    def self.encode_payload(data)
      data.to_json
    end
  end

  def self.event(label, extra_fields = {})
    fields = {
      :label      => label,
      :started_at => Time.now.iso8601,
      :host       => hostname
    }
    fields.merge!(extra_fields)
    forwarder.forward(encode_payload(fields), :routing_key => events_routing_key)
  end

  private

  def self.events_routing_key
    "events.#{application_name}.#{environment_name}"
  end

  def self.forwarder
    @forwarder ||= Forwarders.get(application_name, environment_name)
  end
end
