require "socket"
require "time_bandits"

module LogjamAgent
  module RequestHandling
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

  mattr_accessor :forwarding_error_logger
  self.forwarding_error_logger = nil

  mattr_accessor :error_handler
  self.error_handler = lambda do |exception|
    forwarding_error_logger.error "#{exception.class.name}: #{exception.message}" if forwarding_error_logger
  end

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

  mattr_accessor :obfuscate_ips
  self.obfuscate_ips = false

  # TODO: ipv6 obfuscation
  def self.ip_obfuscator(ip)
    obfuscate_ips ? ip.to_s.sub(/\d+\z/, 'XXX') : ip
  end

  mattr_accessor :obfuscated_cookies
  self.obfuscated_cookies = [/_session\z/]

  def self.cookie_obfuscator
    @cookie_obfuscator ||= ActionDispatch::Http::ParameterFilter.new(obfuscated_cookies)
  end

  extend RequestHandling

  mattr_accessor :exception_classes
  self.exception_classes = []

  mattr_accessor :exception_matcher
  self.exception_matcher = nil

  mattr_accessor :ignore_asset_requests
  self.ignore_asset_requests = false

  mattr_accessor :log_device_ignored_lines
  self.log_device_ignored_lines = nil

  mattr_accessor :log_device_level
  self.log_device_level = Logger::WARN

  def self.log_to_log_device?(severity, msg)
    severity >= log_device_level && !(log_device_ignored_lines && msg =~ log_device_ignored_lines)
  rescue
    true
  end

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
    return if @_exception_auto_detection_initialized
    determine_loaded_exception_classes
    Exception.class_eval <<-"EOS"
      def self.inherited(subclass)
        ::LogjamAgent.auto_detect_exception(subclass)
        ::LogjamAgent.reset_exception_matcher
      end
    EOS
    @_exception_auto_detection_initialized = true
  end

  # setup uuid generation
  begin
    require "uuid4r"
    def self.generate_uuid
      UUID4R::uuid(1).gsub('-','')
    end
  rescue LoadError
    def self.generate_uuid
      SecureRandom.uuid.gsub('-','')
    end
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

  def self.add_forwarder(type, *args)
    case type
    when :zmq then Forwarders.add(ZMQForwarder.new(*args))
    when :amqp then Forwarders.add(AMQPForwarder.new(*args))
    else raise ArgumentError.new("unkown logjam transport: '#{type}'")
    end
  end

  private

  def self.events_routing_key
    "events.#{application_name}.#{environment_name}"
  end

  def self.forwarder
    @forwarder ||= Forwarders.get(application_name, environment_name)
  end
end
