require "test_helper"

# Ｂ部品在庫メンテナンス（旧 hzaikomente.asp）のテスト
class StockbMaintenanceControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @kepart = Kepart.create!(pcode: "E001~", form: "6L28HX", size: "10x20", jname: "和文の名称", ename: "English name",
                             itemno: "7", sel_unit: "10", weightkg: 1.5, munit: 2, newprice: 2500)
    Stockb.create!(partno: "E001~", num: 10, irprice: 2500, ikubun: 1, memo: "入庫メモ")
    Stockb.create!(partno: "E001~", num: -3, irprice: 2500, okubun: 2, mno: 202611001, cname: "メモの会社", sname: "メモの船")
    Adlist.create!(no: "9100", company: "出庫先海運株式会社", ruby: "しゅっこ")
    @order = Order.create!(mno: 202611001, adlist_id: 9100, shipname: "注文の船")
  end

  test "someone who is not signed in is sent to the login screen" do
    delete session_url
    get stockb_maintenance_url(partno: "E001~")
    assert_redirected_to new_session_url(format: :html)
    post stockb_maintenance_hide_url, params: { partno: "E001~" }
    assert_redirected_to new_session_url(format: :html)
    assert_not StockbSetting.for_part("E001~").hidden?
  end

  test "show lists the part, the stock and the history" do
    StockSetting.create!(partno: "E001~", opartno: "OLD001", memo: "補足情報です")
    get stockb_maintenance_url(partno: "E001~")
    assert_response :success
    assert_select "title", /Ｂ部品在庫メンテナンス/
    assert_select "td", text: "6L28HX"
    assert_select "td", text: "10x20"
    assert_select "td", text: "和文の名称"
    assert_select "td", text: "English name"
    assert_select "td", text: "OLD001"
    assert_select "td", text: "補足情報です"
    assert_select "td", text: "7" # 計算在庫数 10-3
    assert_select "td", text: "2,500"
    assert_select "td", text: "7" # ItemNo
    assert_select "table.list-table tbody tr", count: 2
  end

  test "the headers are those of the old screen" do
    get stockb_maintenance_url(partno: "E001~")
    headers = css_select("th").map { |th| th.text.strip }
    assert_includes headers, "寸法"
    assert_includes headers, "ItemNo"
    assert_includes headers, "計算在庫数"
    assert_includes headers, "旧部品コード"
    assert_not_includes headers, "標準在庫数"
    assert_not_includes headers, "予測量"
    assert_not_includes headers, "単価更新"
  end

  test "the part number is accepted in lower case and full-width" do
    get stockb_maintenance_url(partno: "ｅ001~ ")
    assert_response :success
    assert_select "td", text: "和文の名称"
  end

  test "the button to see the definition of the part opens the KE part" do
    get stockb_maintenance_url(partno: "E001~")
    assert_select "a[href=?]", kepart_path(@kepart.id), text: "部品定義参照"
  end

  test "the buttons for a receipt and an issue are in a row with their explanations and open the B screens" do
    get stockb_maintenance_url(partno: "E001~")
    assert_select "table tr td a[href=?]", stockb_in_path(partno: "E001~"), text: "入庫登録"
    assert_select "table tr td a[href=?]", stockb_out_path(partno: "E001~"), text: "出庫登録"
    assert_select "table tr td span.TB12", text: /入荷を登録するには/
    assert_select "table tr td span.TB12", text: /出荷を登録するには/
    row = css_select("tr").find { |tr| tr.at_css("a[href='#{stockb_in_path(partno: 'E001~')}']") }
    assert row.at_css("a[href='#{stockb_out_path(partno: 'E001~')}']")
  end

  test "the history shows the ship of the order and the kinds, with the updated date" do
    get stockb_maintenance_url(partno: "E001~")
    assert_select "table.list-table td a[href=?]", order_path(@order), text: "注文の船"
    assert_select "table.list-table td a[href=?]", order_path(@order), text: "出庫先海運株式会社"
    assert_select "table.list-table td", text: "売掛分"
    assert_select "table.list-table td", text: "買取品　入庫メモ"
    date = css_select("table.list-table tbody tr").first.at_css("td").text.strip
    assert_equal Date.current.strftime("%Y/%m/%d"), date
  end

  test "the history date is the updated date, not the date in the line" do
    Stockb.create!(partno: "E001~", num: 1, irprice: 1, indate: Date.new(2001, 2, 3), outdate: Date.new(2002, 3, 4))
    get stockb_maintenance_url(partno: "E001~")
    assert_no_match(%r{2001/02/03|2002/03/04}, response.body)
  end

  test "only the first 21 rows are listed and past rows can be asked for" do
    25.times { |i| Stockb.create!(partno: "E001~", num: 1, irprice: 1, memo: "行#{i}") }
    get stockb_maintenance_url(partno: "E001~")
    assert_select "table.list-table tbody tr", count: 21
    assert_select "a[href=?]", stockb_maintenance_path(partno: "E001~", all: 1), text: "過去全表示"
    get stockb_maintenance_url(partno: "E001~", all: 1)
    assert_select "table.list-table tbody tr", count: 27
    assert_select "a", text: "過去全表示", count: 0
  end

  test "the history is of the ledger B and not of the ledger A" do
    Stock.create!(partno: "E001~", num: 99, irprice: 1, memo: "Ａ部品の行")
    get stockb_maintenance_url(partno: "E001~")
    assert_no_match(/Ａ部品の行/, response.body)
    assert_select "td", text: "7"
  end

  test "show works for a part that is only in the ledger B" do
    Stockb.create!(partno: "ONLYLEDGER~", num: 3, irprice: 100)
    get stockb_maintenance_url(partno: "ONLYLEDGER~")
    assert_response :success
    assert_select "p", text: /KE部品台帳に登録がない/
    assert_select "a", text: "部品定義参照", count: 0
  end

  test "show without a known part goes back with a message" do
    get stockb_maintenance_url(partno: "NOWHERE~")
    assert_redirected_to menu_url
    follow_redirect!
    assert_match(/部品「NOWHERE~」はKE部品台帳にも在庫台帳Bにも見つかりません/, response.body)
  end

  test "show without a part number goes to the menu" do
    get stockb_maintenance_url
    assert_redirected_to menu_url
  end

  test "hide and reveal change the setting and come back to the screen with a message" do
    get stockb_maintenance_url(partno: "E001~")
    assert_select "input[type=submit][value=非表示設定]:not([disabled])"
    assert_select "input[type=submit][value=表示設定][disabled]"
    assert_select "p", text: /現在は在庫を表示に設定しています/

    post stockb_maintenance_hide_url, params: { partno: "E001~" }
    assert_response :see_other
    assert_redirected_to stockb_maintenance_url(partno: "E001~")
    assert StockbSetting.for_part("E001~").hidden?
    follow_redirect!
    assert_match(/非表示に設定しました/, response.body)
    assert_select "input[type=submit][value=非表示設定][disabled]"
    assert_select "p", text: /現在は在庫を非表示に設定しています/

    post stockb_maintenance_reveal_url, params: { partno: "E001~" }
    assert_not StockbSetting.for_part("E001~").hidden?
    follow_redirect!
    assert_match(/表示に設定しました/, response.body)
  end

  test "hiding takes the part out of the list of the B parts" do
    get stockbs_url(partno: "~")
    assert_select "td a", text: "E001~"
    post stockb_maintenance_hide_url, params: { partno: "E001~" }
    get stockbs_url(partno: "~")
    assert_select "td a", text: "E001~", count: 0
  end

  test "adjust makes the stock the same as the real stock" do
    post stockb_maintenance_adjust_url, params: { partno: "E001~", zaikonum: "12" }
    assert_response :see_other
    assert_redirected_to stockb_maintenance_url(partno: "E001~")
    assert_equal 12, Stockb.on_hand("E001~")
    follow_redirect!
    assert_match(/実在庫 12 に一致化しました/, response.body)
  end

  test "adjust with wrong input changes nothing and says it" do
    assert_no_difference -> { Stockb.count } do
      post stockb_maintenance_adjust_url, params: { partno: "E001~", zaikonum: "abc" }
    end
    assert_redirected_to stockb_maintenance_url(partno: "E001~")
    follow_redirect!
    assert_match(/実在庫数は 0 から 999999 の整数/, response.body)
  end

  test "the routes of the A part maintenance that the B screen does not have are not there" do
    post "/stockb_maintenance/price", params: { partno: "E001~", price: "1" }
    assert_response :not_found
    assert_equal 2500, @kepart.reload.newprice
  end

  test "the explanations are in the annotation style and not on the table headers" do
    get stockb_maintenance_url(partno: "E001~")
    assert_select "span.TB12", text: /入荷を登録するには/
    assert_select "th.TB12, th .TB12", false
  end

  test "the A part maintenance is not changed by the B one" do
    Part.create!(pcode: "E001~", jname: "Ａ部品の名称", newprice: 1)
    Stock.create!(partno: "E001~", num: 2, irprice: 1)
    get stock_maintenance_url(partno: "E001~")
    assert_response :success
    assert_select "td", text: "Ａ部品の名称"
    assert_select "td", text: "和文の名称", count: 0
    post stock_maintenance_hide_url, params: { partno: "E001~" }
    assert StockSetting.for_part("E001~").hidden?
    assert_not StockbSetting.for_part("E001~").hidden?
  end
end
