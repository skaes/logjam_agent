module LogjamAgent
  module SelectiveLogging
    extend self

    mattr_accessor :selective_logging_enabled
    self.selective_logging_enabled = true

    def logjam_only
      old_selector = logjam_log_selector
      self.logjam_log_selector = :logjam_only if selective_logging_enabled
      yield
    ensure
      self.logjam_log_selector = old_selector
    end

    def logdevice_only
      old_selector = logjam_log_selector
      self.logjam_log_selector = :logdevice_only  if selective_logging_enabled
      yield
    ensure
      self.logjam_log_selector = old_selector
    end

    def logjam_log_selector
      Thread.current.thread_variable_get(:logjam_log_selector)
    end

    def logjam_log_selector=(selector)
      Thread.current.thread_variable_set(:logjam_log_selector, selector)
    end

    def logjam_only?
      logjam_log_selector == :logjam_only
    end

    def logdevice_only?
      logjam_log_selector == :logdevice_only
    end
  end
end
