require "test_helper"

class WelcomControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
  end

  test "should get index" do
    get welcom_index_url
    assert_response :success
  end
end
