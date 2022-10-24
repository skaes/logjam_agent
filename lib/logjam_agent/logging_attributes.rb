module LogjamAgent
  module LoggingAttributes

    extend self

    def attributes=(attributes)
      Thread.current.thread_variable_set(:__logjam_agent_logging_attributes__, attributes)
    end

    def attributes
      Thread.current.thread_variable_get(:__logjam_agent_logging_attributes__) ||
        Thread.current.thread_variable_set(:__logjam_agent_logging_attributes__, [])
    end

    def set_attribute(name, value)
      if attribute = attributes.detect{|n,v| n == name}
        attribute[1] = value
      else
        attributes << [name, value]
      end
    end

    def reset_attributes
      self.attributes = []
    end

    def render_attributes
      attrs = non_nil_attributes
      attrs.empty? ? nil : attrs.map{|k,v| "#{k}=#{v}"}.join(" ")
    end

    def non_nil_attributes
      attributes.select{|k,v| !k.nil? }
    end

  end
end
