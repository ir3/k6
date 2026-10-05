require "test_helper"

# 取引台帳修正（orders#edit / orders#update）のテスト。
# update は注文部品詳細の値引き・消費税率の行からも呼ばれるので、その経路も確認する。
class OrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    Registry.create!(country: "日本", countryid: "1")
    Registry.create!(country: "韓国", countryid: "4")
    @adlist = Adlist.create!(no: "9001", company: "テスト海運株式会社", section: "船舶部", section2: "第二課", ruby: "てすとかいうん")
    @other  = Adlist.create!(no: "9002", company: "別の会社", ruby: "べつ")
    @order  = Order.create!(mno: 202610001, adlist_id: 9001, shipname: "第一丸", country: "日本",
                            rdate: Date.new(2026, 10, 15), ncomment: "既存コメント")
  end

  test "edit shows the order in the orderup layout" do
    get edit_order_url(@order)
    assert_response :success
    assert_select "title", /取引台帳修正/
    assert_select "td", text: "テスト海運株式会社"
    assert_select "td", text: "船舶部 第二課"
    assert_select "input[name='order[shipname]'][value='第一丸']"
    assert_select "input[name='order[adlist_id]'][value='9001']"
    assert_select "select[name='order[rdate(1i)]'] option[selected][value='2026']"
  end

  test "edit works even when the adlist of the order no longer exists" do
    @order.update!(adlist_id: 9999)
    get edit_order_url(@order)
    assert_response :success
    assert_select "td", text: "（取引先未登録）"
  end

  test "edit works for an order without a delivery date" do
    @order.update!(rdate: nil)
    get edit_order_url(@order)
    assert_response :success
    assert_select "select[name='order[rdate(1i)]']"
  end

  test "edit keeps a country that is not in the registry selected" do
    @order.update!(country: "クエート")
    get edit_order_url(@order)
    assert_select "select[name='order[country]'] option[selected][value='クエート']"
  end

  test "edit fills the default delivery comment only when it is unset" do
    @order.update!(ncomment: nil)
    get edit_order_url(@order)
    assert_select "textarea[name='order[ncomment]']", text: /御社御下命後４日/

    @order.update!(ncomment: "")
    get edit_order_url(@order)
    assert_select "textarea[name='order[ncomment]']", text: ""
  end

  test "update saves the edited fields" do
    patch order_url(@order), params: { order: {
      shipname: "第二丸", etype: "6L28HX", ono: "A-1", country: "韓国", ncomment: "至急",
      "rdate(1i)" => "2026", "rdate(2i)" => "11", "rdate(3i)" => "30"
    } }
    assert_redirected_to order_url(@order)
    @order.reload
    assert_equal "第二丸", @order.shipname
    assert_equal "6L28HX", @order.etype
    assert_equal "韓国", @order.country
    assert_equal Date.new(2026, 11, 30), @order.rdate
    assert_equal "至急", @order.ncomment
  end

  test "update changes the adlist when it exists" do
    patch order_url(@order), params: { order: { adlist_id: "9002" } }
    assert_redirected_to order_url(@order)
    assert_equal 9002, @order.reload.adlist_id
  end

  test "update rejects an adlist that does not exist" do
    patch order_url(@order), params: { order: { adlist_id: "8888", shipname: "変えない" } }
    assert_response :unprocessable_entity
    assert_select ".alert-error", /取引先が見つかりません/
    @order.reload
    assert_equal 9001, @order.adlist_id
    assert_equal "第一丸", @order.shipname
  end

  test "update rejects an impossible delivery date instead of clearing it" do
    patch order_url(@order), params: { order: { "rdate(1i)" => "2026", "rdate(2i)" => "2", "rdate(3i)" => "31" } }
    assert_response :unprocessable_entity
    assert_select ".alert-error", /納入期日が正しい日付ではありません/
    assert_equal Date.new(2026, 10, 15), @order.reload.rdate
  end

  test "update from the discount and tax rows still works without date or adlist" do
    patch order_url(@order), params: { order: { nebiki: "500" } }
    assert_redirected_to order_url(@order)
    patch order_url(@order), params: { order: { tax_rate: "8" } }
    assert_redirected_to order_url(@order)
    @order.reload
    assert_equal 500, @order.nebiki
    assert_equal 8, @order.tax_rate
    assert_equal Date.new(2026, 10, 15), @order.rdate
    assert_equal 9001, @order.adlist_id
  end

  test "update is not blocked by an adlist that already no longer exists when it is unchanged" do
    @order.update!(adlist_id: 9999)
    patch order_url(@order), params: { order: { adlist_id: "9999", shipname: "修正後" } }
    assert_redirected_to order_url(@order)
    assert_equal "修正後", @order.reload.shipname
  end
end
