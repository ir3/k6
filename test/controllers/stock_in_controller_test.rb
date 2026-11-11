require "test_helper"

# 入庫入力（旧 zaikoin.asp）のテスト。在庫メンテナンスの「入庫登録」から開く
class StockInControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @part = Part.create!(pcode: "A001", form: "6L28HX", jname: "和文の名称", ename: "English name",
                         sel_unit: "10", weightkg: 1.5, munit: 2, newprice: 2500)
    Stock.create!(partno: "A001", num: 10, irprice: 2500)
    Stock.create!(partno: "A001", num: -3, irprice: 2500)
  end

  def entry(overrides = {})
    { partno: "A001", num: "5", price: "2500", ikubun: "1" }.merge(overrides)
  end

  test "someone who is not signed in is sent to the login screen" do
    delete session_url
    get stock_in_url(partno: "A001")
    assert_redirected_to new_session_url(format: :html)
    assert_no_difference -> { Stock.count } do
      post stock_in_url, params: entry
    end
    assert_redirected_to new_session_url(format: :html)
  end

  test "new shows the part, the current stock and the empty entry" do
    get stock_in_url(partno: "A001")
    assert_response :success
    assert_select "title", /入庫入力/
    assert_select "td", text: "A001"
    assert_select "td", text: "6L28HX"
    assert_select "td", text: "和文の名称"
    assert_select "td", text: "English name"
    assert_select "td", text: "2,500"         # 販売単価
    assert_select "td", text: "7"             # 現在在庫数 10-3
    assert_select "td", text: "10"            # 販売単位
    assert_select "input[type=hidden][name=partno][value=A001]"
    assert_select "input[name=price][value=2500]"  # 仕入時販売単価は販売単価がはじめから入っている
    assert_select "input[name=num]:not([value])"
    assert_select "textarea[name=memo]"
    assert_select "input[name=ship]"
    assert_select "input[name=company]"
    assert_select "input[type=submit][value=入庫登録]"
  end

  test "new has the four kinds of the receipt and the first one is chosen" do
    get stock_in_url(partno: "A001")
    kinds = css_select("input[name=ikubun]")
    assert_equal %w[1 2 3 4], kinds.map { |input| input["value"] }
    assert_equal [ "1" ], kinds.select { |input| input["checked"] }.map { |input| input["value"] }
    labels = css_select("label").map { |label| label.text.strip }
    Stock::INBOUND_KINDS.each_value { |name| assert_includes labels, name }
  end

  test "new finds the part without regard to case and full-width" do
    get stock_in_url(partno: "ａ001 ")
    assert_response :success
    assert_select "td", text: "A001"
  end

  test "new without a part number asks for the part number" do
    get stock_in_url
    assert_response :success
    assert_select "form[action=?][method=get]", stock_in_path
    assert_select "input[name=partno]"
    assert_select "input[type=submit][value=?]", "部品番号を入力して部品選択"
    assert_select "input[name=price]", false
  end

  test "new with an unknown part goes back to the part number entry with a message" do
    get stock_in_url(partno: "NOWHERE")
    assert_redirected_to stock_in_url
    follow_redirect!
    assert_match(/部品「NOWHERE」は部品台帳にも在庫台帳にも見つかりません/, response.body)
  end

  test "new works for a part that is only in the stock ledger" do
    Stock.create!(partno: "LEDGERONLY", num: 2)
    get stock_in_url(partno: "LEDGERONLY")
    assert_response :success
    assert_select "td", text: "LEDGERONLY"
    assert_select "p.TB12", text: /部品台帳に登録がない/
    assert_select "input[name=price]:not([value])"
  end

  test "create adds the receipt and goes back to the stock maintenance with a message" do
    assert_difference -> { Stock.count }, 1 do
      post stock_in_url, params: entry(num: "5", ikubun: "3", memo: "返品です", ship: "五色丸", company: "テスト海運")
    end
    assert_response :see_other
    assert_redirected_to stock_maintenance_url(partno: "A001")
    row = Stock.reorder(:id).last
    assert_equal [ "A001", 5, 2500, 3, 0 ], [ row.partno, row.num, row.irprice, row.ikubun, row.okubun ]
    assert_equal [ "返品です", "五色丸", "テスト海運" ], [ row.memo, row.sname, row.cname ]
    follow_redirect!
    assert_match(/A001 を 5 入庫登録しました/, response.body)
    assert_equal 12, Stock.on_hand("A001")
  end

  test "create reduces the number on order, and the stock list shows it" do
    Stock.create!(partno: "A001", num: 0, onum: 8)
    post stock_in_url, params: entry(num: "5")
    assert_equal(-5, Stock.reorder(:id).last.onum)
    row = StockList.new.rows.find { |r| r.pcode == "A001" }
    assert_equal 3, row.ordered
  end

  test "create with wrong input shows the form again with the message and what was typed" do
    assert_no_difference -> { Stock.count } do
      post stock_in_url, params: entry(num: "abc", price: "2800", ikubun: "4", memo: "書いた備考", ship: "新星丸", company: "会社")
    end
    assert_response :unprocessable_entity
    assert_match(/入庫数は 1 から 999999 の整数で入力してください/, response.body)
    assert_select "input[name=num][value=abc]"
    assert_select "input[name=price][value=2800]"
    assert_select "textarea[name=memo]", text: "書いた備考"
    assert_select "input[name=ship][value=?]", "新星丸"
    assert_select "input[name=company][value=?]", "会社"
    assert_select "input[name=ikubun][value='4'][checked]"
    assert_select "td", text: "7" # 現在在庫数は変わらず7
  end

  test "create with a price that is not a number is refused" do
    assert_no_difference -> { Stock.count } do
      post stock_in_url, params: entry(price: "")
    end
    assert_response :unprocessable_entity
    assert_match(/仕入時販売単価/, response.body)
  end

  test "create with an unknown part is refused" do
    assert_no_difference -> { Stock.count } do
      post stock_in_url, params: entry(partno: "NOWHERE")
    end
    assert_redirected_to stock_in_url
  end

  test "create without a part number is refused" do
    assert_no_difference -> { Stock.count } do
      post stock_in_url, params: entry(partno: "")
    end
    assert_redirected_to stock_in_url
  end

  test "create does not change the price of the part" do
    post stock_in_url, params: entry(price: "2800")
    assert_equal 2500, @part.reload.newprice
    assert_equal 2800, Stock.reorder(:id).last.irprice
  end

  test "the stock maintenance screen has the button to open the entry of the part" do
    get stock_maintenance_url(partno: "A001")
    assert_select "a[href=?]", stock_in_path(partno: "A001"), text: "入庫登録"
  end

  test "the explanations are in the annotation style and not on the table headers" do
    get stock_in_url(partno: "A001")
    assert_select "p.TB12", text: /単価に修正があれば新単価も入力します/
    assert_select "span.TB12", text: /入庫数を入力後/
    assert_select "th.TB12, th .TB12", false
  end
end
