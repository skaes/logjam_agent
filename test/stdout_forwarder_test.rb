require_relative "test_helper.rb"

module LogjamAgent
  class STDOUTForwarderTest < MiniTest::Test

    test "sets up forwarder with empty config" do
      f = STDOUTForwarder.new
      assert_equal({}, f.instance_variable_get("@config"))
    end

    test "encodes the payload without compression" do
      data = {a: 1, b: "str"}
      msg = LogjamAgent.json_encode_payload(data)
      f = STDOUTForwarder.new
      $stdout.expects(:write).with("#{msg}\n")
      f.forward(data, :routing_key => "x", :app_env => "a-b")
    end

  end
end
