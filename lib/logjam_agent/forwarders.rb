module LogjamAgent
  module Forwarders
    @@forwarders = {}

    extend self

    def add(f)
      @@forwarders["#{f.app}-#{f.env}"] = f
    end

    def get(app, env)
      @@forwarders["#{app}-#{env}"]
    end

    def reset
      @@forwarders.each_value {|f| f.reset}
    end

    def inspect
      super + ": #{@@forwarders.inspect}"
    end
  end
end
