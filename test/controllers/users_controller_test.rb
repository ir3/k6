require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @user = users(:two)
    sign_in_as @admin
  end

  test "should get index" do
    get users_url
    assert_response :success
  end

  test "should get new" do
    get new_user_url
    assert_response :success
  end

  test "should show user" do
    get user_url(@user)
    assert_response :success
  end

  test "should get edit" do
    get edit_user_url(@user)
    assert_response :success
  end

  test "should update user" do
    patch user_url(@user), params: { user: { email_address: @user.email_address } }
    assert_redirected_to user_url(@user)
  end

  test "should destroy user (soft delete)" do
    delete user_url(@user)
    assert_redirected_to users_url
    assert_equal "offline", @user.user_profile.reload.state
  end
end
