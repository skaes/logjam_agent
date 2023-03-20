require_relative "test_helper.rb"

module LogjamAgent
  class ObfuscatorTest < MiniTest::Test
    include Obfuscation

    test "obfuscates session cookie by default" do
      filter = LogjamAgent.cookie_obfuscator
      assert_equal "_session=[FILTERED]", filter_pairs("_session=data", filter)
      assert_equal "my_session=[FILTERED]", filter_pairs("my_session=mdata", filter)
      assert_equal "blabber=1; _session=[FILTERED]", filter_pairs("blabber=1; _session=data", filter)
      assert_equal "blabber=1; _session=[FILTERED]; blubber=2", filter_pairs("blabber=1; _session=data; blubber=2", filter)
    end

    test "obfuscates with complex regex" do
      filter = ParameterFilter.new([/(login|_session)\z/])
      assert_equal "_session=[FILTERED]; login=[FILTERED]", filter_pairs("_session=my_session; login=foo", filter)
      assert_equal "_session=[FILTERED]; my_login=[FILTERED]", filter_pairs("_session=my_session; my_login=foo", filter)
    end

    test "obfuscates with exact matches" do
      filter = ParameterFilter.new([/\A(login|.*_session)\z/])
      assert_equal "_session=[FILTERED]; login=[FILTERED]", filter_pairs("_session=my_session; login=foo", filter)
      assert_equal "_session=[FILTERED]; my_login=foo", filter_pairs("_session=my_session; my_login=foo", filter)
      assert_equal "my_session=[FILTERED]; my_login=foo", filter_pairs("my_session=my_session; my_login=foo", filter)
    end
  end
end
