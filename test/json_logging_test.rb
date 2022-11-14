require_relative "test_helper.rb"

module LogjamAgent
  class JsonLoggingTest < MiniTest::Test
    def setup
      @request = LogjamAgent.request = Request.new("app", "env", {})
      @lines = @request.instance_variable_get :@lines
      @logger = BufferedLogger.new(File::NULL)
      @device = MockLogDev.new
      @logger.logdev = @device
    end

    def teardown
      LogjamAgent.log_format = :text
      LogjamAgent.request = nil
      LogjamAgent.selective_logging_enabled = true
    end

    def test_can_log_strings_in_json
      LogjamAgent.log_format = :json
      @logger.info("a silly string")
      assert_equal 1, @lines.size
      assert_equal "a silly string", @lines.first.last
      assert_equal 1, @device.lines.size
      assert_match(/"message":"a silly string"}\n/, @device.lines.first)
    end

    def test_can_log_hashes_in_json
      LogjamAgent.log_format = :json
      @logger.info({a: 1})
      assert_equal 1, @lines.size
      assert_equal '{"a":1}', @lines.first.last
      assert_equal 1, @device.lines.size
      assert_match(/\{"a":1\}\n/, @device.lines.first)
    end

    def test_can_log_exceptions_in_json
      LogjamAgent.log_format = :json
      @logger.error(StandardError.new("look ma, an exeption!"))
      assert_equal 1, @lines.size
      assert_equal 'StandardError(look ma, an exeption!)', @lines.first.last
      assert_equal 1, @device.lines.size
      assert_match(/ERROR -- : \{"message":"look ma, an exeption!","error":"StandardError\(look ma, an exeption!\)"\}\n/, @device.lines.first)
    end

    def test_can_log_exceptions_with_backtrace_as_json
      LogjamAgent.log_format = :json
      e = raise "murks" rescue $!
      @logger.error(e)
      assert_equal 1, @lines.size
      assert_match(/RuntimeError\(murks\):(\n.*\.rb:\d+:in\s.*)+/, @lines.first.last)
      assert_equal 1, @device.lines.size
      assert_match(/ERROR -- : {"message":"murks","error":"RuntimeError\(murks\):(\\n.*\.rb:\d+:in\s.*)+"}\n/, @device.lines.first)
    end

    def test_log_syntax_in_json
      LogjamAgent.log_format = :json
      h = {a: 1}
      @logger.info(message: "foo", **h)
      assert_equal 1, @lines.size
      assert_equal '{"message":"foo","a":1}', @lines.first.last
      assert_equal 1, @device.lines.size
      assert_match(/\{"message":"foo","a":1\}\n/, @device.lines.first)
    end

    def test_can_log_strings_as_text
      LogjamAgent.log_format = :text
      @logger.info("a silly string")
      assert_equal 1, @lines.size
      assert_equal "a silly string", @lines.first.last
      assert_equal 1, @device.lines.size
      assert_match(/INFO  -- : a silly string\n/, @device.lines.first)
    end

    def test_can_log_hashes_as_text
      LogjamAgent.log_format = :text
      @logger.info({a: 1})
      assert_equal 1, @lines.size
      assert_equal '{"a":1}', @lines.first.last
      assert_equal 1, @device.lines.size
      assert_match(/\{"a":1\}\n/, @device.lines.first)
    end

    def test_can_log_exceptions_as_text
      LogjamAgent.log_format = :text
      @logger.error(StandardError.new("look ma, an exeption!"))
      assert_equal 1, @lines.size
      assert_equal 'StandardError(look ma, an exeption!)', @lines.first.last
      assert_equal 1, @device.lines.size
      assert_match(/ERROR -- : StandardError\(look ma, an exeption!\)\n/, @device.lines.first)
    end

    def test_can_log_exceptions_with_backtrace_as_text
      LogjamAgent.log_format = :text
      e = raise "murks" rescue $!
      @logger.error(e)
      assert_equal 1, @lines.size
      assert_match(/RuntimeError\(murks\):(\n.*\.rb:\d+:in\s.*)+/, @lines.first.last)
      assert_equal 1, @device.lines.size
      assert_match(/ERROR -- : RuntimeError\(murks\):(\n.*\.rb:\d+:in\s.*)+/, @device.lines.first)
    end

    def test_can_log_arrays_as_text
      LogjamAgent.log_format = :text
      @logger.error([1, 2])
      assert_equal 1, @lines.size
      assert_equal([1, 2].to_s, @lines.first.last)
      assert_equal 1, @device.lines.size
      assert_match(/ERROR -- : \[1, 2\]\n/, @device.lines.first)
    end

    def test_can_log_arrays_as_json
      LogjamAgent.log_format = :json
      @logger.error([1, 2])
      assert_equal 1, @lines.size
      assert_equal([1, 2].to_s, @lines.first.last)
      assert_equal 1, @device.lines.size
      assert_match(/ERROR -- : \{"message":"\[1, 2\]"\}\n/, @device.lines.first)
    end
  end
end
