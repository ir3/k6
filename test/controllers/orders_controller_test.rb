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

  test "edit no longer has the rate and discount fields" do
    get edit_order_url(@order)
    assert_select "input[name='order[irate]']", false
    assert_select "input[name='order[irate2]']", false
    assert_select "input[name='order[nebiki]']", false
  end

  test "update from the edit screen leaves the rates and discount untouched" do
    @order.update!(irate: 0.8, irate2: 0.9, nebiki: 100)
    # 編集画面は掛け率・値引きを送らない
    patch order_url(@order), params: { order: { shipname: "第二丸" } }
    assert_redirected_to order_url(@order)
    @order.reload
    assert_equal [ 0.8, 0.9, 100 ], [ @order.irate, @order.irate2, @order.nebiki ]
  end

  test "edit shows the updated time right after the order number and has no separate row for it" do
    get edit_order_url(@order)
    assert_select "table.edit-table", 1
    heads = css_select("table.edit-table tr").first.css("th").map { |th| th.text.strip }
    assert_equal %w[納入期日 管理番号 更新日時], heads
    assert_select "table.edit-table tr:first-child td", text: @order.updated_at.strftime("%Y/%m/%d %H:%M")
  end

  test "edit uses 6 rows for the memo and 2 rows for the delivery comment" do
    get edit_order_url(@order)
    assert_select "textarea[name='order[memo]'][rows='6']"
    assert_select "textarea[name='order[ncomment]'][rows='2']"
  end

  test "edit puts T/C to MG No. on two rows of four pairs" do
    get edit_order_url(@order)
    rows = css_select("table.edit-table tr").map { |tr| tr.css("input[name^='order[']").map { |i| i["name"] } }
    tc_rows = rows.select { |names| names.include?("order[tc]") || names.include?("order[glc]") }
    assert_equal [ %w[order[tc] order[tcno] order[zp] order[zpno]],
                   %w[order[glc] order[glcno] order[mg] order[mgno]] ], tc_rows
  end

  test "edit lays the kana buttons out in order, 15 per row, with the remainder joined to the last row" do
    get edit_order_url(@order)
    rows = css_select("form .flex.flex-col > .flex").map { |row| row.css("a").map { |a| a.text.strip } }
    assert_equal [ 15, 15, 17 ], rows.map(&:size)
    assert_equal %w[あ い う え お か き く け こ さ し す せ そ], rows.first
    assert_equal %w[ろ わ を ん 全], rows.last.last(5)
  end

  test "edit has a button that goes back to the order without saving" do
    get edit_order_url(@order)
    assert_select "a.btn[href='#{order_path(@order)}']", text: "修正しないで戻り"
    assert_select "button[type='reset']", false
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

  # --- 注文部品詳細の掛け率入力 ---

  test "show has rate inputs that submit to update, and no discount column in the rate row" do
    get order_url(@order)
    assert_response :success
    assert_select "form#order_rate_form[action='#{order_path(@order)}'] input[name='_method'][value='patch']"
    assert_select "input[name='order[irate]'][form='order_rate_form']"
    assert_select "input[name='order[irate2]'][form='order_rate_form']"
    assert_select "input[type='submit'][form='order_rate_form']"
    assert_select "th", text: /値引き/, count: 0
  end

  test "update saves the rates sent from the order screen" do
    patch order_url(@order), params: { order: { irate: "0.85", irate2: "0.9" } }
    assert_redirected_to order_url(@order)
    @order.reload
    assert_equal [ 0.85, 0.9 ], [ @order.irate, @order.irate2 ]
  end

  test "update treats blank rates as unset" do
    @order.update!(irate: 0.8, irate2: 0.9)
    patch order_url(@order), params: { order: { irate: "", irate2: "" } }
    assert_redirected_to order_url(@order)
    @order.reload
    assert_nil @order.irate
    assert_nil @order.irate2
  end

  test "update rejects rates that are not plain non-negative numbers and goes back to the order" do
    @order.update!(irate: 0.8, irate2: 0.9)
    [ "abc", "-1", "0x1A", "1e3", "1_0", "0.8.1" ].each do |bad|
      patch order_url(@order), params: { order: { irate: bad, shipname: "変えない" } }
      assert_redirected_to order_url(@order), "irate=#{bad}"
      @order.reload
      assert_equal 0.8, @order.irate, "irate=#{bad}"
      assert_equal "第一丸", @order.shipname, "irate=#{bad}"
      follow_redirect!
      assert_select ".alert-error", /掛け率/
    end
  end

  test "update does not blow up when a date part is sent as an array" do
    patch order_url(@order), params: { order: { "rdate(1i)" => [ "2026" ], "rdate(2i)" => "11", "rdate(3i)" => "30" } }
    assert_response :redirect
  end
end
