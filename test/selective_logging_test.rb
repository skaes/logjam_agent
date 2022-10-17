require_relative "test_helper.rb"

module LogjamAgent
  class SelectiveLoggingTest < MiniTest::Test
    class MockLogDev
      attr_reader :lines
      def initialize
        @lines = []
      end
      def write(s)
        @lines << s
      end
    end

    def setup
      @request = LogjamAgent.request = Request.new("app", "env", {})
      @lines = @request.instance_variable_get :@lines
      @logger = BufferedLogger.new(File::NULL)
      @device = MockLogDev.new
      @logger.logdev = @device
    end

    def teardown
      LogjamAgent.request = nil
    end

    def test_normal_logging_adds_line_to_request_and_logdevice
      assert !LogjamAgent.logjam_only?
      assert !LogjamAgent.logdevice_only?
      @logger.info("normal")
      assert_equal 1, @lines.size
      assert_equal "normal", @lines.first.last
      assert_equal 1, @device.lines.size
      assert_match(/normal\n/, @device.lines.first)
    end

    def test_logjam_only_logging_adds_line_to_request_but_not_to_logdevice
      LogjamAgent.logjam_only do
        assert LogjamAgent.logjam_only?
        assert !LogjamAgent.logdevice_only?
        @logger.info("logjam_only")
      end
      assert_equal 1, @lines.size
      assert_equal "logjam_only", @lines.first.last
      assert_equal 0, @device.lines.size
    end

    def test_logdevice_only_logging_adds_line_to_logdevice_but_not_to_request
      LogjamAgent.logdevice_only do
        assert !LogjamAgent.logjam_only?
        assert LogjamAgent.logdevice_only?
        @logger.info("logdevice_only")
      end
      assert_equal [], @lines
      assert_equal 1, @device.lines.size
      assert_match(/logdevice_only\n/, @device.lines.first)
    end
  end
end
