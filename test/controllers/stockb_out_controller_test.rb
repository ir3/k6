require "test_helper"

# Ｂ部品出庫入力（旧 zaikoout2.asp → syukoEntry2.asp）のテスト。Ｂ部品在庫メンテナンスの「出庫登録」から開く
class StockbOutControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @kepart = Kepart.create!(pcode: "E001~", form: "6L28HX", jname: "和文の名称", ename: "English name",
                             sel_unit: "10", weightkg: 1.5, munit: 2, newprice: 2500)
    Stockb.create!(partno: "E001~", num: 10, irprice: 2500)
    Stockb.create!(partno: "E001~", num: -3, irprice: 2500)
    Adlist.create!(no: "9100", company: "出庫先海運株式会社", ruby: "しゅっこ")
    @order = Order.create!(mno: 202611001, adlist_id: 9100, shipname: "注文の船")
  end

  def entry(overrides = {})
    { partno: "E001~", num: "2", price: "2500", okubun: "2" }.merge(overrides)
  end

  test "someone who is not signed in is sent to the login screen" do
    delete session_url
    get stockb_out_url(partno: "E001~")
    assert_redirected_to new_session_url(format: :html)
    assert_no_difference -> { Stockb.count } do
      post stockb_out_url, params: entry
    end
  end

  test "new shows the part and the current stock of the B part with the B title" do
    get stockb_out_url(partno: "E001~")
    assert_response :success
    assert_select "title", /Ｂ部品出庫入力/
    assert_select "td", text: "E001~"
    assert_select "td", text: "7"
    assert_select "form[action=?][method=post]", stockb_out_path
    assert_select "input[type=submit][value=出庫登録]"
    assert_select "a[href=?]", stockb_maintenance_path(partno: "E001~"), text: "戻る"
    assert_equal [ "2" ], css_select("input[name=okubun]").select { |i| i["checked"] }.map { |i| i["value"] }
  end

  test "new with an order number fills the ship and the company from the order" do
    get stockb_out_url(partno: "E001~", mno: "202611001")
    assert_select "input[name=mno][value=202611001]"
    assert_select "input[name=ship][value=?]", "注文の船"
    assert_select "input[name=company][value=?]", "出庫先海運株式会社"
  end

  test "new without a part number asks for the part number and keeps the order number" do
    get stockb_out_url(mno: "202611001")
    assert_response :success
    assert_select "form[action=?][method=get]", stockb_out_path
    assert_select "input[type=hidden][name=mno][value=202611001]"
  end

  test "new with an unknown part goes back to the B part number entry with a message" do
    get stockb_out_url(partno: "NOWHERE")
    assert_redirected_to stockb_out_url
    follow_redirect!
    assert_match(/KE部品台帳にも在庫台帳Bにも見つかりません/, response.body)
  end

  test "create adds the issue to the ledger B and goes back to the B maintenance with a message" do
    assert_no_difference -> { Stock.count } do
      assert_difference -> { Stockb.count }, 1 do
        post stockb_out_url, params: entry(num: "2", okubun: "1", mno: "202611001", memo: "貸出です", ship: "注文の船", company: "出庫先海運株式会社")
      end
    end
    assert_response :see_other
    assert_redirected_to stockb_maintenance_url(partno: "E001~")
    row = Stockb.reorder(:id).last
    assert_equal [ "E001~", -2, 2500, 1, 202611001, 0 ], [ row.partno, row.num, row.irprice, row.okubun, row.mno, row.kind ]
    assert_equal Date.current, row.indate
    follow_redirect!
    assert_match(/E001~ を 2 出庫登録しました/, response.body)
    assert_equal 5, Stockb.on_hand("E001~")
  end

  test "the issue shows in the history of the B maintenance with the ship of the order" do
    post stockb_out_url, params: entry(mno: "202611001")
    get stockb_maintenance_url(partno: "E001~")
    assert_select "table.list-table td a[href=?]", order_path(@order), text: "注文の船"
  end

  test "create with wrong input or an order that is not in the ledger shows the form again" do
    assert_no_difference -> { Stockb.count } do
      post stockb_out_url, params: entry(num: "abc", mno: "202611001", ship: "新星丸")
      assert_response :unprocessable_entity
      assert_match(/出庫数は 1 から 999999 の整数で入力してください/, response.body)
      assert_select "input[name=ship][value=?]", "新星丸"
      assert_select "form[action=?]", stockb_out_path

      post stockb_out_url, params: entry(mno: "202699999")
      assert_response :unprocessable_entity
      assert_match(/202699999/, response.body)
    end
  end

  test "create with an unknown part or without a part number is refused" do
    assert_no_difference -> { Stockb.count } do
      post stockb_out_url, params: entry(partno: "NOWHERE")
      assert_redirected_to stockb_out_url
      post stockb_out_url, params: entry(partno: "")
      assert_redirected_to stockb_out_url
    end
  end
  test "new takes the quantity that is passed as the first value like the A part stock out" do
    get stockb_out_url(partno: "E001~", num: "5")
    assert_select "input[name=num][value=5]"
    get stockb_out_url(partno: "E001~", num: "0")
    assert_select "input[name=num]:not([value])"
  end
  # 「戻る」は、開いたときの直前のページ（飛び元）に戻る
  def back_href
    css_select("a").find { |link| link.text.strip == "戻る" }["href"]
  end

  test "the back button goes to the page the B part stock out screen was opened from" do
    origin = order_url(@order)
    get stockb_out_url(partno: "E001~"), headers: { "HTTP_REFERER" => origin }
    assert_equal URI.parse(origin).request_uri, back_href
  end

  test "the back button keeps going to the first page after a wrong entry shows the B part stock out screen again" do
    origin = order_url(@order)
    get stockb_out_url(partno: "E001~"), headers: { "HTTP_REFERER" => origin }
    post stockb_out_url, params: { partno: "E001~", num: "abc", price: "2500", okubun: "2" }, headers: { "HTTP_REFERER" => stockb_out_url(partno: "E001~") }
    assert_response :unprocessable_entity
    assert_equal URI.parse(origin).request_uri, back_href
  end

  test "the back button of the B part stock out screen goes to the stock maintenance without a previous page" do
    get stockb_out_url(partno: "E001~")
    assert_equal stockb_maintenance_path(partno: "E001~"), back_href
  end

  test "the back button of the B part stock out screen opened from the stock maintenance goes back to it" do
    get stockb_out_url(partno: "E001~"), headers: { "HTTP_REFERER" => stockb_maintenance_url(partno: "E001~") }
    assert_equal stockb_maintenance_path(partno: "E001~"), back_href
  end

  test "a page of another site is not used as the back button of the B part stock out screen" do
    get stockb_out_url(partno: "E001~"), headers: { "HTTP_REFERER" => "https://evil.example.com/x" }
    assert_equal stockb_maintenance_path(partno: "E001~"), back_href
  end
end
