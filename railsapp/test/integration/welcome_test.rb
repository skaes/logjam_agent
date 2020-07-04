require 'test_helper'

class WelcomeTest < ActionDispatch::IntegrationTest
  test "serve a page with logjam" do
    get "/"
    assert_response :success
  end
end
