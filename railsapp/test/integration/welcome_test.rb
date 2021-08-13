require 'test_helper'

class WelcomeTest < ActionDispatch::IntegrationTest
  setup do
    @@receiver ||= LogjamAgent::Receiver.new
  end

  def logjam_message
     @@receiver.receive
  end

  test "serve a page with logjam" do
    get "/?password=bamf"
    assert_response :success
  ensure
    stream, topic, payload = logjam_message
    assert_equal "railsapp-test", stream
    assert_equal "logs.railsapp.test", topic
    assert_equal 200, payload["code"]
    assert_equal "WelcomeController#index", payload["action"]
    assert_kind_of Float, payload["total_time"]
    assert_kind_of String, payload["started_at"]
    assert_kind_of Integer, payload["started_ms"]
    assert_kind_of String, payload["ip"]
    assert_kind_of Float, payload["view_time"]
    assert_kind_of String, payload["trace_id"]
    lines = payload["lines"]
    # puts "Rails::VERSION::STRING: #{Rails::VERSION::STRING}"
    # lines.each{|l|puts l[2]}
    assert_match(/Started GET "\/\?password=\[FILTERED\]"/, lines[0][2])
    assert_match(/Processing by WelcomeController#index/, lines[1][2])
    assert_match(/Parameters.*{"password"=>"\[FILTERED\]"/, lines[2][2])
    if Gem::Version.new(Rails::VERSION::STRING) >= Gem::Version.new("6.1")
      assert_match(/Rendering/, lines[3][2])
      assert_match(/Rendering/, lines[4][2])
      assert_match(/Rendered/, lines[5][2])
      assert_match(/Rendered/, lines[6][2])
      assert_match(/Completed 200 OK/, lines[7][2])
      assert_nil(lines[8])
    else
      assert_match(/Rendering/, lines[3][2])
      assert_match(/Rendered/, lines[4][2])
      assert_match(/Completed 200 OK/, lines[5][2])
      assert_nil(lines[6])
    end
    request_info = payload["request_info"]
    method, url, query_parameters = request_info.values_at(*%w(method url query_parameters))
    assert_equal method, "GET"
    assert_equal url, "/?password=[FILTERED]"
    assert_equal(query_parameters, { "password" => "[FILTERED]" })
  end

  test "a page raising an exception passes it through to the test" do
    assert_raises(StandardError) { get "/?raise=1" }
  ensure
    payload = logjam_message[2]
    assert_equal 500, payload["code"]
    assert_equal "WelcomeController#index", payload["action"]
    assert_kind_of Float, payload["total_time"]
    assert_kind_of String, payload["started_at"]
    assert_kind_of Integer, payload["started_ms"]
    assert_kind_of String, payload["ip"]
    request_info = payload["request_info"]
    method, url, query_parameters = request_info.values_at(*%w(method url query_parameters))
    assert_equal method, "GET"
    assert_equal url, "/?raise=1"
    assert_equal(query_parameters, { "raise" => "1" })
  end

  test "forwards trace id and caller fields to logjam" do
    trace_id = LogjamAgent.generate_uuid
    caller_id = "foo-bar-123"
    caller_action = "MayController#index"
    get "/?password=bamf", headers: {
          "HTTP_X_LOGJAM_TRACE_ID" => trace_id,
          "HTTP_X_LOGJAM_CALLER_ID" => caller_id,
          "HTTP_X_LOGJAM_ACTION" => caller_action,
        }
    assert_response :success
  ensure
    stream, topic, payload = logjam_message
    assert_equal "railsapp-test", stream
    assert_equal "logs.railsapp.test", topic
    assert_equal trace_id, payload["trace_id"]
    assert_equal caller_id, payload["caller_id"]
    assert_equal caller_action, payload["caller_action"]
  end

end
