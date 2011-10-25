require "socket"
require "logjam_agent/version"
require "logjam_agent/amqp_forwarder"
require "logjam_agent/forwarders"
require "logjam_agent/request"
require "logjam_agent/buffered_logger"
require "logjam_agent/syslog_like_formatter"

module LogjamAgent

  class ForwardingError < StandardError; end

  mattr_accessor :error_handler
  self.error_handler = lambda { |exception| }

  mattr_accessor :application_name
  self.application_name = nil

  mattr_accessor :environment_name
  self.environment_name = nil

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

end
