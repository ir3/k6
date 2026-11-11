require "test_helper"

# メニュー。ログインしていないまま要求したら、HOME（ログインが要る）へ飛ばす。
class MenusControllerTest < ActionDispatch::IntegrationTest
  test "ログインしていないままメニューを要求すると HOME へ飛ぶ" do
    get menu_url
    assert_redirected_to welcom_index_url
  end

  test "ログインしていなければ、HOME からさらにログイン画面へ進む" do
    get menu_url
    follow_redirect!
    assert_redirected_to new_session_url(format: :html)
  end

  test "未ログインでメニューを要求したあと、ログイン後に戻る先はメニューにしない（HOME → メニューの通常の流れ）" do
    get menu_url
    follow_redirect!
    post session_url, params: { email_address: users(:one).email_address, password: "password" }
    # HOME で止まったあとにログインしたのだから、HOME へ戻る（HOME が自動でメニューへ進む）
    assert_redirected_to welcom_index_url
  end

  test "未ログインのメニューの更新（PATCH）も HOME へ飛ばし、設定は変えない" do
    assert_no_difference -> { Ksystem.count } do
      patch menu_tax_rate_url, params: { default_tax_rate: "20" }
    end
    assert_redirected_to welcom_index_url
    patch menu_sales_person_url, params: { sales_person: "誰か" }
    assert_redirected_to welcom_index_url
  end

  test "ログインしていればメニューが開く" do
    sign_in_as users(:one)
    get menu_url
    assert_response :success
  end
end
