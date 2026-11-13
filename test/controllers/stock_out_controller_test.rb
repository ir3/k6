require "test_helper"

# 出庫入力（旧 zaikoout.asp）のテスト。在庫メンテナンスの「出庫登録」から開く
class StockOutControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @part = Part.create!(pcode: "A001", form: "6L28HX", jname: "和文の名称", ename: "English name",
                         sel_unit: "10", weightkg: 1.5, munit: 2, newprice: 2500)
    Stock.create!(partno: "A001", num: 10, irprice: 2500)
    Stock.create!(partno: "A001", num: -3, irprice: 2500)
    Adlist.create!(no: "9100", company: "出庫先海運株式会社", ruby: "しゅっこ")
    @order = Order.create!(mno: 202611001, adlist_id: 9100, shipname: "注文の船")
  end

  def entry(overrides = {})
    { partno: "A001", num: "2", price: "2500", okubun: "2" }.merge(overrides)
  end

  test "someone who is not signed in is sent to the login screen" do
    delete session_url
    get stock_out_url(partno: "A001")
    assert_redirected_to new_session_url(format: :html)
    assert_no_difference -> { Stock.count } do
      post stock_out_url, params: entry
    end
    assert_redirected_to new_session_url(format: :html)
  end

  test "new shows the part, the current stock and the empty entry" do
    get stock_out_url(partno: "A001")
    assert_response :success
    assert_select "title", /出庫入力/
    assert_select "td", text: "A001"
    assert_select "td", text: "6L28HX"
    assert_select "td", text: "和文の名称"
    assert_select "td", text: "English name"
    assert_select "td", text: "2,500"         # 販売単価
    assert_select "td", text: "7"             # 現在在庫数 10-3
    assert_select "td", text: "10"            # 販売単位
    assert_select "input[type=hidden][name=partno][value=A001]"
    assert_select "input[name=price][value=2500]"
    assert_select "input[name=num]:not([value])"
    assert_select "input[name=mno]:not([value])"
    assert_select "input[name=memo]"
    assert_select "input[name=ship]:not([value])"
    assert_select "input[name=company]:not([value])"
    assert_select "input[type=submit][value=出庫登録]"
  end

  test "new has the two kinds of the issue and the credit sale is chosen" do
    get stock_out_url(partno: "A001")
    kinds = css_select("input[name=okubun]")
    assert_equal %w[1 2], kinds.map { |input| input["value"] }
    assert_equal [ "2" ], kinds.select { |input| input["checked"] }.map { |input| input["value"] }
    labels = css_select("label").map { |label| label.text.strip }
    Stock::OUTBOUND_KINDS.each_value { |name| assert_includes labels, name }
  end

  test "new with an order number fills the ship and the company from the order" do
    get stock_out_url(partno: "A001", mno: "202611001")
    assert_select "input[name=mno][value=202611001]"
    assert_select "input[name=ship][value=?]", "注文の船"
    assert_select "input[name=company][value=?]", "出庫先海運株式会社"
  end

  test "new with an order number that is not in the ledger leaves the ship and the company empty" do
    get stock_out_url(partno: "A001", mno: "202699999")
    assert_response :success
    assert_select "input[name=ship]:not([value])"
    assert_select "input[name=company]:not([value])"
  end

  test "new finds the part without regard to case and full-width" do
    get stock_out_url(partno: "ａ001 ")
    assert_response :success
    assert_select "td", text: "A001"
  end

  test "new without a part number asks for the part number" do
    get stock_out_url
    assert_response :success
    assert_select "form[action=?][method=get]", stock_out_path
    assert_select "input[name=partno]"
    assert_select "input[type=submit][value=?]", "部品番号を入力して部品選択"
    assert_select "input[name=price]", false
  end

  test "new with an unknown part goes back to the part number entry with a message" do
    get stock_out_url(partno: "NOWHERE")
    assert_redirected_to stock_out_url
    follow_redirect!
    assert_match(/部品「NOWHERE」は部品台帳にも在庫台帳にも見つかりません/, response.body)
  end

  test "new works for a part that is only in the stock ledger" do
    Stock.create!(partno: "LEDGERONLY", num: 2)
    get stock_out_url(partno: "LEDGERONLY")
    assert_response :success
    assert_select "td", text: "LEDGERONLY"
    assert_select "p.TB12", text: /部品台帳に登録がない/
    assert_select "input[name=price]:not([value])"
  end

  test "create adds the issue and goes back to the stock maintenance with a message" do
    assert_difference -> { Stock.count }, 1 do
      post stock_out_url, params: entry(num: "2", okubun: "1", mno: "202611001", memo: "貸出です", ship: "注文の船", company: "出庫先海運株式会社")
    end
    assert_response :see_other
    assert_redirected_to stock_maintenance_url(partno: "A001")
    row = Stock.reorder(:id).last
    assert_equal [ "A001", -2, 2500, 1, 202611001 ], [ row.partno, row.num, row.irprice, row.okubun, row.mno ]
    assert_equal [ "貸出です", "注文の船", "出庫先海運株式会社" ], [ row.memo, row.sname, row.cname ]
    follow_redirect!
    assert_match(/A001 を 2 出庫登録しました/, response.body)
    assert_equal 5, Stock.on_hand("A001")
  end

  test "create without an order number is fine" do
    post stock_out_url, params: entry(mno: "")
    assert_redirected_to stock_maintenance_url(partno: "A001")
    assert_equal 0, Stock.reorder(:id).last.mno
  end

  test "the issue shows in the history of the maintenance screen with the ship of the order" do
    post stock_out_url, params: entry(mno: "202611001")
    get stock_maintenance_url(partno: "A001")
    assert_select "table.list-table td a[href=?]", order_path(@order), text: "注文の船"
  end

  test "create with wrong input shows the form again with the message and what was typed" do
    assert_no_difference -> { Stock.count } do
      post stock_out_url, params: entry(num: "abc", price: "2800", okubun: "1", mno: "202611001", memo: "書いた備考", ship: "新星丸", company: "会社")
    end
    assert_response :unprocessable_entity
    assert_match(/出庫数は 1 から 999999 の整数で入力してください/, response.body)
    assert_select "input[name=num][value=abc]"
    assert_select "input[name=price][value=2800]"
    assert_select "input[name=mno][value=202611001]"
    assert_select "input[name=memo][value=?]", "書いた備考"
    assert_select "input[name=ship][value=?]", "新星丸"
    assert_select "input[name=company][value=?]", "会社"
    assert_select "input[name=okubun][value='1'][checked]"
    assert_select "td", text: "7" # 現在在庫数は変わらず7
  end

  test "create with an order number that is not in the ledger is refused and keeps the form" do
    assert_no_difference -> { Stock.count } do
      post stock_out_url, params: entry(mno: "202699999")
    end
    assert_response :unprocessable_entity
    assert_match(/202699999/, response.body)
    assert_select "input[name=mno][value=202699999]"
  end

  test "create with a price that is not a number is refused" do
    assert_no_difference -> { Stock.count } do
      post stock_out_url, params: entry(price: "")
    end
    assert_response :unprocessable_entity
    assert_match(/仕入時販売単価/, response.body)
  end

  test "create with an unknown part is refused" do
    assert_no_difference -> { Stock.count } do
      post stock_out_url, params: entry(partno: "NOWHERE")
    end
    assert_redirected_to stock_out_url
  end

  test "create without a part number is refused" do
    assert_no_difference -> { Stock.count } do
      post stock_out_url, params: entry(partno: "")
    end
    assert_redirected_to stock_out_url
  end

  test "create does not change the price of the part" do
    post stock_out_url, params: entry(price: "2800")
    assert_equal 2500, @part.reload.newprice
    assert_equal 2800, Stock.reorder(:id).last.irprice
  end

  test "the explanations are in the annotation style and not on the table headers" do
    get stock_out_url(partno: "A001")
    assert_select "p.TB12", text: /出庫数と出庫先/
    assert_select "span.TB12", text: /出庫の取引の 管理番号を入力/
    assert_select "span.TB12", text: /出庫数を入力後/
    assert_select "th.TB12, th .TB12", false
  end
  # 出庫数の初期値（?num=。注文部品詳細の「この部品を在庫から引き当て、在庫数を減算する」が、明細の数量を渡す）
  test "new takes the quantity that is passed as the first value of the quantity to take out" do
    get stock_out_url(partno: "A001", mno: "202611001", num: "3")
    assert_select "input[name=num][value=3]"
    assert_select "input[name=mno][value=202611001]"
    assert_select "input[name=ship][value=?]", "注文の船"
  end

  test "a quantity that cannot be taken out is not used as the first value" do
    [ "0", "-2", "abc", "1.5", "", "1000000" ].each do |bad|
      get stock_out_url(partno: "A001", num: bad)
      assert_response :success
      assert_select "input[name=num]:not([value])"
    end
    get stock_out_url(partno: "A001", num: "２")
    assert_select "input[name=num][value=2]"
  end

  test "the first value is only shown, nothing is taken out until the entry is registered" do
    assert_no_difference -> { Stock.count } do
      get stock_out_url(partno: "A001", mno: "202611001", num: "4")
    end
  end
end
