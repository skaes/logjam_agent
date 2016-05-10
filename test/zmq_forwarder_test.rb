require_relative "test_helper.rb"

module LogjamAgent
  class ZMQForwarderTest < MiniTest::Test

    test "sets up single connection with default port" do
      f = ZMQForwarder.new(:host => "a.b.c", :port => 3001)
      assert_equal ["tcp://a.b.c:3001"], f.connection_specs
    end

    test "sets up multiple connections" do
      f = ZMQForwarder.new(:host => "a.b.c,tcp://x.y.z:9000,zmq.gnu.org:600")
      assert_equal %w(tcp://a.b.c:9605 tcp://x.y.z:9000 tcp://zmq.gnu.org:600), f.connection_specs
    end

  end
end
