require_relative "test_helper.rb"
require_relative "sinatra_classic_app"
require "rack/test"

module LogjamAgent
  class SinatraClassicTest < MiniTest::Test

    include ::Rack::Test::Methods

    def app
      ::Sinatra::Application
    end

    def test_root
      get '/index?mumu=1&password=5'
      assert_equal 'Hello World!', last_response.body
    end

  end
end
