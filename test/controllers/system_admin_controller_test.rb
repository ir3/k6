require "test_helper"

# システム管理画面（ナビバーの 管理者 → システム管理）のテスト。管理者のみ入れる。
class SystemAdminControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)    # state 9
    @normal = users(:two)   # state 1
  end

  test "an admin sees the versions of Ruby, Rails, Node.js, Tailwind CSS and daisyUI" do
    sign_in_as @admin
    get system_admin_url
    assert_response :success
    assert_select "title", /システム管理/
    assert_select "td", text: "Ruby"
    assert_select "td", text: RUBY_VERSION
    assert_select "td", text: "Rails"
    assert_select "td", text: Rails.version
    %w[Node.js Tailwind\ CSS daisyUI].each do |name|
      assert_select "td", text: name
    end
    assert_select "tbody tr", count: 5
  end

  test "the versions that could not be read are shown as 不明" do
    # 読めなかった項目は version が nil。差し替えずにビューだけ描画して確かめる
    items = [ SystemInfo::Item.new("daisyUI", nil, "node_modules"),
             SystemInfo::Item.new("Ruby", "4.0.9", "実行中のプロセス") ]
    html = ApplicationController.render(template: "system_admin/show", assigns: { items: items }, layout: false)
    page = Nokogiri::HTML5.fragment(html)
    assert_select page, "tbody tr", count: 2
    assert_select page, "td", text: "不明", count: 1
    assert_select page, "td", text: "4.0.9"
  end

  test "the explanation of where the versions come from is in the annotation style" do
    sign_in_as @admin
    get system_admin_url
    assert_select "p.TB12", text: /\.node-version/
    assert_select "th.TB12, th .TB12", false
  end

  test "a normal user is sent back to the menu with a message" do
    sign_in_as @normal
    get system_admin_url
    assert_redirected_to menu_url
    assert_equal "管理者のみアクセスできます。", flash[:alert]
  end

  test "a manager is not allowed either, only an admin is" do
    @normal.user_profile.update!(state: :manager)
    sign_in_as @normal
    get system_admin_url
    assert_redirected_to menu_url
    assert_equal "管理者のみアクセスできます。", flash[:alert]
  end

  test "someone who is not signed in is sent to the login screen" do
    get system_admin_url
    assert_redirected_to new_session_url(format: :html)
  end

  test "the admin menu in the navbar has システム管理 for an admin" do
    sign_in_as @admin
    get menu_url
    assert_select "ul.dropdown-content a[href=?]", system_admin_path, text: "システム管理"
  end

  test "the admin menu is shown to a manager but without システム管理" do
    @normal.user_profile.update!(state: :manager)
    sign_in_as @normal
    get menu_url
    assert_select "ul.dropdown-content a[href=?]", users_path
    assert_select "a[href=?]", system_admin_path, false
  end
end
