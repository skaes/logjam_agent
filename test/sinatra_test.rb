require_relative "test_helper.rb"
require_relative "sinatra_app"
require "rack/test"

module LogjamAgent
  class SinatraTest < MiniTest::Test

    include ::Rack::Test::Methods

    def app
      SinatraTestApp
    end

    def test_root
      get '/index?mumu=1&password=5'
      assert_equal 'Hello World!', last_response.body
    end

  end
end
