require "test_helper"

# Ｂ部品入庫入力（旧 zaikoin2.asp → nyukoEntry2.asp）のテスト。Ｂ部品在庫メンテナンスの「入庫登録」から開く
class StockbInControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @kepart = Kepart.create!(pcode: "E001~", form: "6L28HX", jname: "和文の名称", ename: "English name",
                             sel_unit: "10", weightkg: 1.5, munit: 2, newprice: 2500)
    Stockb.create!(partno: "E001~", num: 10, irprice: 2500)
    Stockb.create!(partno: "E001~", num: -3, irprice: 2500)
  end

  def entry(overrides = {})
    { partno: "E001~", num: "5", price: "2500", ikubun: "1" }.merge(overrides)
  end

  test "someone who is not signed in is sent to the login screen" do
    delete session_url
    get stockb_in_url(partno: "E001~")
    assert_redirected_to new_session_url(format: :html)
    assert_no_difference -> { Stockb.count } do
      post stockb_in_url, params: entry
    end
  end

  test "new shows the part and the current stock of the B part with the B title" do
    get stockb_in_url(partno: "E001~")
    assert_response :success
    assert_select "title", /Ｂ部品入庫入力/
    assert_select "td", text: "E001~"
    assert_select "td", text: "和文の名称"
    assert_select "td", text: "7" # 現在在庫数 10-3
    assert_select "form[action=?][method=post]", stockb_in_path
    assert_select "input[type=hidden][name=partno][value=?]", "E001~"
    assert_select "input[name=price][value=2500]"
    assert_select "input[type=submit][value=入庫登録]"
    assert_select "a[href=?]", stockb_maintenance_path(partno: "E001~"), text: "戻る"
  end

  test "new does not show the stock of the A part with the same code" do
    Stock.create!(partno: "E001~", num: 1000)
    get stockb_in_url(partno: "E001~")
    assert_select "td", text: "7"
    assert_select "td", text: "1007", count: 0
  end

  test "new without a part number asks for the part number and goes to the B screen" do
    get stockb_in_url
    assert_response :success
    assert_select "form[action=?][method=get]", stockb_in_path
    assert_select "input[name=partno]"
  end

  test "new with an unknown part goes back to the B part number entry with a message" do
    get stockb_in_url(partno: "NOWHERE")
    assert_redirected_to stockb_in_url
    follow_redirect!
    assert_match(/部品「NOWHERE」はKE部品台帳にも在庫台帳Bにも見つかりません/, response.body)
  end

  test "new does not know a part that is only in the A part ledgers" do
    Part.create!(pcode: "ONLYA")
    get stockb_in_url(partno: "ONLYA")
    assert_redirected_to stockb_in_url
  end

  test "new says that a part not in the KE part ledger has no information" do
    Stockb.create!(partno: "LEDGERONLY~", num: 2)
    get stockb_in_url(partno: "LEDGERONLY~")
    assert_response :success
    assert_select "p.TB12", text: /KE部品台帳に登録がない/
  end

  test "create adds the receipt to the ledger B and goes back to the B maintenance with a message" do
    assert_no_difference -> { Stock.count } do
      assert_difference -> { Stockb.count }, 1 do
        post stockb_in_url, params: entry(num: "5", ikubun: "3", memo: "返品です")
      end
    end
    assert_response :see_other
    assert_redirected_to stockb_maintenance_url(partno: "E001~")
    row = Stockb.reorder(:id).last
    assert_equal [ "E001~", 5, 2500, 1, 3 ], [ row.partno, row.num, row.irprice, row.kind, row.ikubun ]
    assert_nil row.indate
    follow_redirect!
    assert_match(/E001~ を 5 入庫登録しました/, response.body)
    assert_equal 12, Stockb.on_hand("E001~")
  end

  test "create with wrong input shows the form again with the message and what was typed" do
    assert_no_difference -> { Stockb.count } do
      post stockb_in_url, params: entry(num: "abc", price: "2800", ikubun: "4", memo: "書いた備考")
    end
    assert_response :unprocessable_entity
    assert_match(/入庫数は 1 から 999999 の整数で入力してください/, response.body)
    assert_select "input[name=num][value=abc]"
    assert_select "input[name=price][value=2800]"
    assert_select "textarea[name=memo]", text: "書いた備考"
    assert_select "input[name=ikubun][value='4'][checked]"
    assert_select "form[action=?]", stockb_in_path
  end

  test "create with an unknown part or without a part number is refused" do
    assert_no_difference -> { Stockb.count } do
      post stockb_in_url, params: entry(partno: "NOWHERE")
      assert_redirected_to stockb_in_url
      post stockb_in_url, params: entry(partno: "")
      assert_redirected_to stockb_in_url
    end
  end

  test "create does not change the price of the KE part" do
    post stockb_in_url, params: entry(price: "2800")
    assert_equal 2500, @kepart.reload.newprice
  end
  # 「戻る」は、開いたときの直前のページ（飛び元）に戻る
  def back_href
    css_select("a").find { |link| link.text.strip == "戻る" }["href"]
  end

  test "the back button goes to the page the B part stock in screen was opened from" do
    origin = keparts_url
    get stockb_in_url(partno: "E001~"), headers: { "HTTP_REFERER" => origin }
    assert_equal URI.parse(origin).request_uri, back_href
  end

  test "the back button keeps going to the first page after a wrong entry shows the B part stock in screen again" do
    origin = keparts_url
    get stockb_in_url(partno: "E001~"), headers: { "HTTP_REFERER" => origin }
    post stockb_in_url, params: { partno: "E001~", num: "abc", price: "2500", ikubun: "1" }, headers: { "HTTP_REFERER" => stockb_in_url(partno: "E001~") }
    assert_response :unprocessable_entity
    assert_equal URI.parse(origin).request_uri, back_href
  end

  test "the back button of the B part stock in screen goes to the stock maintenance without a previous page" do
    get stockb_in_url(partno: "E001~")
    assert_equal stockb_maintenance_path(partno: "E001~"), back_href
  end

  test "the back button of the B part stock in screen opened from the stock maintenance goes back to it" do
    get stockb_in_url(partno: "E001~"), headers: { "HTTP_REFERER" => stockb_maintenance_url(partno: "E001~") }
    assert_equal stockb_maintenance_path(partno: "E001~"), back_href
  end

  test "a page of another site is not used as the back button of the B part stock in screen" do
    get stockb_in_url(partno: "E001~"), headers: { "HTTP_REFERER" => "https://evil.example.com/x" }
    assert_equal stockb_maintenance_path(partno: "E001~"), back_href
  end
end
