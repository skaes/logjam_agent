require_relative "test_helper.rb"

module LogjamAgent
  class AMQPForwarderTest < MiniTest::Test
    def setup
      AMQPForwarder.any_instance.expects(:ensure_bunny_gem_is_available)
    end

    def teardown
      LogjamAgent.compression_method = NO_COMPRESSION
    end

    test "encodes the payload" do
      data = {a: 1, b: "str"}
      msg = LogjamAgent.encode_payload(data)
      f = AMQPForwarder.new
      f.expects(:publish).with("a-b", "x", msg)
      f.forward(data, :routing_key => "x", :app_env => "a-b")
    end

    test "compressed message using snappy can be uncompressed" do
      data = {a: 1, b: "str"}
      normal_msg = LogjamAgent.encode_payload(data)
      LogjamAgent.compression_method = SNAPPY_COMPRESSION
      compressed_msg = LogjamAgent.encode_payload(data)
      assert_equal normal_msg, Snappy.inflate(compressed_msg)
      f = AMQPForwarder.new
      f.expects(:publish).with("a-b", "x", compressed_msg)
      f.forward(data, :routing_key => "x", :app_env => "a-b")
    end
  end
end
