require_relative "test_helper.rb"

module LogjamAgent
  class RequestTest < MiniTest::Test

    def setup
      @request = Request.new("app", "env", {})
      @request.instance_eval do
        @max_bytes_all_lines = 100
        @max_line_length = 50
      end
    end

    TRUNCATED_LINE = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxx ... [LINE TRUNCATED]"

    def test_truncates_lines_longer_than_max_line_length
      @request.add_line(Logger::INFO, Time.now, "x" * 51)
      assert_equal 1, lines(@request).size
      assert_equal TRUNCATED_LINE, lines(@request).first[2]
    end

    def test_truncates_messages_larger_than_max_bytes_all_lines
      @request.add_line(Logger::INFO, Time.now, "x" * 150)
      assert_equal 1, lines(@request).size
      assert_equal TRUNCATED_LINE, lines(@request).first[2]
    end

    def test_does_not_truncate_error_lines_if_overall_message_size_is_still_ok
      @request.add_line(Logger::ERROR, Time.now, "x" * 70)
      assert_equal 1, lines(@request).size
      assert_equal "x" * 70, lines(@request).first[2]
    end

    def test_truncates_long_error_lines_if_message_size_is_larger_than_max_bytes_all_lines
      @request.add_line(Logger::ERROR, Time.now, "x" * 120)
      assert_equal 1, lines(@request).size
      assert_equal TRUNCATED_LINE, lines(@request)[0][2]
    end

    def test_truncates_long_lines_if_message_size_is_larger_than_max_bytes_all_lines
      @request.add_line(Logger::INFO, Time.now, "y" * 80)
      @request.add_line(Logger::ERROR, Time.now, "x" * 80)
      assert_equal 2, lines(@request).size
      assert_equal TRUNCATED_LINE, lines(@request)[1][2]
    end

    private

    def lines(request)
      request.instance_variable_get :@lines
    end
  end
end
