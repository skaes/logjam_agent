require_relative "test_helper.rb"

module LogjamAgent
  class ObfuscatorTest < MiniTest::Test
    include Obfuscation

    test "obfuscates session cookie by default" do
      assert_equal "_session=[FILTERED]", obfuscate_cookie("_session=data")
      assert_equal "my_session=[FILTERED]", obfuscate_cookie("my_session=mdata")
      assert_equal "blabber=1; _session=[FILTERED]", obfuscate_cookie("blabber=1; _session=data")
      assert_equal "blabber=1; _session=[FILTERED]; blubber=2", obfuscate_cookie("blabber=1; _session=data; blubber=2")
    end

    test "obfuscates with complex regex" do
      filter = ParameterFilter.new([/(login|_session)\z/])
      assert_equal "_session=[FILTERED]; login=[FILTERED]",  obfuscate_cookie("_session=my_session; login=foo", filter)
      assert_equal "_session=[FILTERED]; my_login=[FILTERED]",  obfuscate_cookie("_session=my_session; my_login=foo", filter)
    end

    test "obfuscates with exact matches" do
      filter = ParameterFilter.new([/\A(login|.*_session)\z/])
      assert_equal "_session=[FILTERED]; login=[FILTERED]",  obfuscate_cookie("_session=my_session; login=foo", filter)
      assert_equal "_session=[FILTERED]; my_login=foo",  obfuscate_cookie("_session=my_session; my_login=foo", filter)
      assert_equal "my_session=[FILTERED]; my_login=foo",  obfuscate_cookie("my_session=my_session; my_login=foo", filter)
    end
  end
end
