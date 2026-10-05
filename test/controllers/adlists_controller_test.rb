require "test_helper"

# 取引台帳修正の取引先選択モーダル（adlists#picker）のテスト
class AdlistsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @a = Adlist.create!(no: "9001", company: "青空海運", section: "船舶部", section2: "第二課", ruby: "あおぞらかいうん")
    @ka = Adlist.create!(no: "9002", company: "海鳥産業", ruby: "かもめさんぎょう")
    @ga = Adlist.create!(no: "9003", company: "雁金商事", ruby: "がんがねしょうじ")
    @kata = Adlist.create!(no: "9004", company: "カワサキ", ruby: "カワサキ")
  end

  test "picker narrows by the first kana and returns rows the modal can pick" do
    get adlists_picker_url(gyo: "あ")
    assert_response :success
    assert_select "tr[data-no='9001'][data-company='青空海運'][data-section='船舶部 第二課']"
    assert_select "tr[data-no='9002']", false
  end

  test "picker includes voiced and katakana readings for a kana" do
    get adlists_picker_url(gyo: "か")
    assert_select "tr[data-no='9002']"
    assert_select "tr[data-no='9003']"
    assert_select "tr[data-no='9004']"
    assert_select "tr[data-no='9001']", false
  end

  test "picker without a kana lists everything" do
    get adlists_picker_url
    assert_response :success
    assert_select "tr[data-no]", 4
  end

  test "picker is wrapped in the adlist_picker turbo frame" do
    get adlists_picker_url(gyo: "あ")
    assert_select "turbo-frame#adlist_picker"
  end

  test "picker requires login" do
    delete session_url
    get adlists_picker_url(gyo: "あ")
    assert_redirected_to new_session_url(format: :html)
  end
end
