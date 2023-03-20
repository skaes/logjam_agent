module LogjamAgent
  module Obfuscation

    mattr_accessor :obfuscate_ips
    self.obfuscate_ips = false

    # TODO: ipv6 obfuscation
    def ip_obfuscator(ip)
      obfuscate_ips ? ip.to_s.sub(/\d+\z/, 'XXX') : ip
    end

    mattr_accessor :obfuscated_cookies
    self.obfuscated_cookies = [/_session\z/]

    def cookie_obfuscator
      @cookie_obfuscator ||= ParameterFilter.new(obfuscated_cookies)
    end

    begin
      # rails 6.1 and higher
      require "active_support/parameter_filter"
      ParameterFilter = ::ActiveSupport::ParameterFilter
    rescue LoadError
      # rails 6.0 and older
      require "action_dispatch/http/parameter_filter"
      ParameterFilter = ::ActionDispatch::Http::ParameterFilter
    end

    KEY_RE = '[^&;=\s]+'
    VAL_RE = '[^&;=]+'
    PAIR_RE = %r{(#{KEY_RE})=(#{VAL_RE})}

    def filter_pairs(str, filter)
      str.gsub(PAIR_RE) do |_|
        filter.filter($1 => $2).first.join("=")
      end
    end

  end
end
