require_relative "test_helper.rb"

module LogjamAgent
  class ZMQForwarderTest < MiniTest::Test

    def teardown
      LogjamAgent.compression_method = NO_COMPRESSION
    end

    test "sets up single connection with default port" do
      f = ZMQForwarder.new(:host => "a.b.c", :port => 3001)
      assert_equal ["tcp://a.b.c:3001"], f.connection_specs
    end

    test "sets up multiple connections" do
      f = ZMQForwarder.new(:host => "a.b.c,tcp://x.y.z:9000,zmq.gnu.org:600")
      assert_equal %w(tcp://a.b.c:9604 tcp://x.y.z:9000 tcp://zmq.gnu.org:600), f.connection_specs
    end

    test "encodes the payload" do
      data = {a: 1, b: "str"}
      msg = LogjamAgent.encode_payload(data)
      f = ZMQForwarder.new
      f.expects(:publish).with("a-b", "x", msg)
      f.forward(data, :routing_key => "x", :app_env => "a-b")
    end

    test "compressed message using snappy can be uncompressed" do
      data = {a: 1, b: "str"}
      normal_msg = LogjamAgent.encode_payload(data)
      LogjamAgent.compression_method = SNAPPY_COMPRESSION
      compressed_msg = LogjamAgent.encode_payload(data)
      assert_equal normal_msg, LogjamAgent.decode_payload(compressed_msg)
      f = ZMQForwarder.new
      f.expects(:publish).with("a-b", "x", compressed_msg)
      f.forward(data, :routing_key => "x", :app_env => "a-b")
    end

    test "compressed message using lz4 can be uncompressed" do
      data = {a: 1, b: "str"}
      normal_msg = LogjamAgent.encode_payload(data)
      LogjamAgent.compression_method = LZ4_COMPRESSION
      compressed_msg = LogjamAgent.encode_payload(data)
      assert_equal normal_msg, LogjamAgent.decode_payload(compressed_msg)
      f = ZMQForwarder.new
      f.expects(:publish).with("a-b", "x", compressed_msg)
      f.forward(data, :routing_key => "x", :app_env => "a-b")
    end

    test "compressed message using zlib can be uncompressed" do
      data = {a: 1, b: "str"}
      normal_msg = LogjamAgent.encode_payload(data)
      LogjamAgent.compression_method = ZLIB_COMPRESSION
      compressed_msg = LogjamAgent.encode_payload(data)
      assert_equal normal_msg, LogjamAgent.decode_payload(compressed_msg)
      f = ZMQForwarder.new
      f.expects(:publish).with("a-b", "x", compressed_msg)
      f.forward(data, :routing_key => "x", :app_env => "a-b")
    end

    test "can log forwarding warnings if error_handler is defined" do
      msg = nil
      LogjamAgent.expects(:error_handler).returns(->(m){ msg = m})
      ZMQForwarder.new.__send__(:log_warning, "xxx")
      assert_instance_of ForwardingWarning, msg
      assert_equal "xxx", msg.message
    end

    test "does not log forwading warnings if error_handler is nil" do
      msg = nil
      LogjamAgent.expects(:error_handler).returns(nil)
      ZMQForwarder.new.__send__(:log_warning, "xxx")
      assert_nil msg
    end

  end
end
