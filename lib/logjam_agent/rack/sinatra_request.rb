require 'sinatra/base'

# Extend the Sinatra Request class with some methods to make it look more like an
# ActionDispatch request.

class Sinatra::Request
  alias_method :method, :request_method
  def query_parameters; self.GET; end
  def request_parameters; self.POST; end

  def parameter_filter
    ActiveSupport::ParameterFilter.new(LogjamAgent.parameter_filters)
  end

  KV_RE   = '[^&;=]+'
  PAIR_RE = %r{(#{KV_RE})=(#{KV_RE})}

  def filtered_path
    return path if query_string.empty?
    filter = parameter_filter
    filtered_query_string = query_string.gsub(PAIR_RE) do |_|
      filter.filter($1 => $2).first.join("=")
    end
    "#{path}?#{filtered_query_string}"
  end

end
