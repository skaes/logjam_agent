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
  end
end
