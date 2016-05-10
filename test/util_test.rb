require_relative "test_helper.rb"

module LogjamAgent
  class UtilTest < MiniTest::Test
    include LogjamAgent::Util

    test "does not change a full spec" do
      augmented = augment_connection_spec("tcp://a:1", 2)
      assert_equal "tcp://a:1", augmented
    end

    test "adds default port when missing" do
      augmented = augment_connection_spec("tcp://a", 1)
      assert_equal "tcp://a:1", augmented
    end

    test "adds default protocol when missing" do
      augmented = augment_connection_spec("a:1", 2)
      assert_equal "tcp://a:1", augmented
    end

    test "adds default protocol and default port when missing" do
      augmented = augment_connection_spec("a", 1)
      assert_equal "tcp://a:1", augmented
    end

  end
end
