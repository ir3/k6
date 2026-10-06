require "test_helper"

# 在庫メンテナンス（旧 zaikomente.asp）のテスト
class StockMaintenanceControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @part = Part.create!(pcode: "A001", form: "6L28HX", jname: "和文の名称", ename: "English name",
                         sel_unit: "10", weightkg: 1.5, munit: 2, newprice: 2500)
    Stock.create!(partno: "A001", num: 10, irprice: 2500, ikubun: 1, memo: "入庫メモ")
    Stock.create!(partno: "A001", num: -3, irprice: 2500, okubun: 2, mno: 202610001, cname: "メモの会社", sname: "メモの船")
    @adlist = Adlist.create!(no: "9001", company: "テスト海運株式会社", ruby: "てすと")
    @order = Order.create!(mno: 202610001, adlist_id: 9001, shipname: "注文の船")
  end

  test "show lists the part, the stock numbers and the history" do
    StockSetting.create!(partno: "A001", snum: 4, znum: 6, opartno: "OLD001", memo: "補足情報です")
    get stock_maintenance_url(partno: "A001")
    assert_response :success
    assert_select "title", /在庫メンテナンス/
    assert_select "td", text: "A001"
    assert_select "td", text: "OLD001"
    assert_select "td", text: "6L28HX"
    assert_select "td", text: "和文の名称"
    assert_select "td", text: "English name"
    assert_select "td", text: "補足情報です"
    # 計算在庫数 10-3=7、標準在庫数4、予測量6
    assert_select "td", text: "7", minimum: 1
    assert_select "input[name='zaikonum'][value='7']"
    assert_select "input[name='snum'][value='4']"
    assert_select "input[name='znum'][value='6']"
    assert_select "input[name='price'][value='2500']"
    assert_select "td", text: "2,500", minimum: 1
  end

  test "show lists the history with the order links" do
    get stock_maintenance_url(partno: "A001")
    assert_select "table.list-table tbody tr", count: 2
    # 出庫の行は取引台帳の注文から会社・船名を出し、注文部品詳細へリンクする
    assert_select "table.list-table td a[href=?]", order_path(@order), text: "テスト海運株式会社"
    assert_select "table.list-table td a[href=?]", order_path(@order), text: "注文の船"
    assert_select "table.list-table td a[href=?]", order_path(@order), text: "202610001"
    assert_select "table.list-table td", text: "売掛分"
    assert_select "table.list-table td", text: "買取品　入庫メモ"
  end

  test "the part number is accepted in lower case" do
    get stock_maintenance_url(partno: "a001")
    assert_response :success
    assert_select "td", text: "和文の名称"
  end

  test "only the first 21 rows are listed and past rows can be asked for" do
    25.times { |i| Stock.create!(partno: "A001", num: 1, irprice: 1, memo: "行#{i}") }
    get stock_maintenance_url(partno: "A001")
    assert_select "table.list-table tbody tr", count: 21
    assert_select "a[href=?]", stock_maintenance_path(partno: "A001", all: 1), text: "過去全表示"
    assert_select "p", text: /全 27 件/

    get stock_maintenance_url(partno: "A001", all: 1)
    assert_select "table.list-table tbody tr", count: 27
    assert_select "a", text: "過去全表示", count: 0
  end

  test "show works for a part that is only in the stock ledger" do
    Stock.create!(partno: "ONLYLEDGER", num: 3, irprice: 100)
    get stock_maintenance_url(partno: "ONLYLEDGER")
    assert_response :success
    assert_select "p", text: /部品台帳に登録がない/
    assert_select "input[type=submit][value='単価更新'][disabled]"
    assert_select "input[name='price']", false
  end

  test "show sends an unknown part back with a message" do
    get stock_maintenance_url(partno: "NOPE")
    assert_redirected_to menu_url
    assert_match(/部品「NOPE」は部品台帳にも在庫台帳にも見つかりません/, flash[:alert])
  end

  test "show without a part number goes to the menu with a message" do
    get stock_maintenance_url
    assert_redirected_to menu_url
    assert_match(/部品番号が指定されていません/, flash[:alert])
  end

  test "the hide and show buttons follow the current setting" do
    get stock_maintenance_url(partno: "A001")
    assert_select "input[type=submit][value='非表示設定']:not([disabled])"
    assert_select "input[type=submit][value='表示設定'][disabled]"
    assert_select "p", text: /在庫を表示に設定しています/

    StockSetting.create!(partno: "A001", nonview: 1)
    get stock_maintenance_url(partno: "A001")
    assert_select "input[type=submit][value='非表示設定'][disabled]"
    assert_select "input[type=submit][value='表示設定']:not([disabled])"
    assert_select "p", text: /在庫を非表示に設定しています/
  end

  test "each update form posts to its own action with the part number" do
    get stock_maintenance_url(partno: "A001")
    { price: stock_maintenance_price_path, hide: stock_maintenance_hide_path, reveal: stock_maintenance_reveal_path,
      adjust: stock_maintenance_adjust_path, standard: stock_maintenance_standard_path,
      forecast: stock_maintenance_forecast_path }.each do |name, path|
      assert_select "form#stock_form_#{name}[action=?][method='post'] input[name='partno'][value='A001']", path
    end
  end

  test "price updates the new sale price and comes back with a message" do
    post stock_maintenance_price_url, params: { partno: "A001", price: "3000" }
    assert_redirected_to stock_maintenance_url(partno: "A001")
    assert_equal 303, response.status
    assert_match(/3,000 円/, flash[:notice])
    assert_equal 3000, @part.reload.newprice
  end

  test "price refuses invalid input with a message" do
    post stock_maintenance_price_url, params: { partno: "A001", price: "abc" }
    assert_redirected_to stock_maintenance_url(partno: "A001")
    assert_match(/整数で入力してください/, flash[:alert])
    assert_equal 2500, @part.reload.newprice
  end

  test "adjust registers an adjustment row and the stock matches" do
    assert_difference -> { Stock.count }, 1 do
      post stock_maintenance_adjust_url, params: { partno: "A001", zaikonum: "9" }
    end
    assert_redirected_to stock_maintenance_url(partno: "A001")
    assert_match(/実在庫 9 に一致化/, flash[:notice])
    assert_equal 9, Stock.on_hand("A001")
    follow_redirect!
    assert_select "table.list-table tbody tr", count: 3
    # 差が正の調整行は入庫区分1(買取品)なので、備考は区分名つきになる
    assert_select "table.list-table td", text: "買取品　調整"
  end

  test "adjust refuses invalid input and registers nothing" do
    assert_no_difference -> { Stock.count } do
      post stock_maintenance_adjust_url, params: { partno: "A001", zaikonum: "-1" }
    end
    assert_match(/整数で入力してください/, flash[:alert])
  end

  test "standard and forecast are saved and shown" do
    post stock_maintenance_standard_url, params: { partno: "A001", snum: "5" }
    post stock_maintenance_forecast_url, params: { partno: "A001", znum: "8" }
    setting = StockSetting.find_by!(partno: "A001")
    assert_equal [ 5, 8 ], [ setting.snum, setting.znum ]
    get stock_maintenance_url(partno: "A001")
    assert_select "input[name='snum'][value='5']"
    assert_select "input[name='znum'][value='8']"
  end

  test "hide and reveal switch the setting" do
    post stock_maintenance_hide_url, params: { partno: "A001" }
    assert StockSetting.find_by!(partno: "A001").hidden?
    assert_match(/非表示に設定/, flash[:notice])
    post stock_maintenance_reveal_url, params: { partno: "A001" }
    assert_not StockSetting.find_by!(partno: "A001").hidden?
    assert_match(/表示に設定/, flash[:notice])
  end

  test "an update without a part number goes to the menu and changes nothing" do
    assert_no_difference -> { Stock.count + StockSetting.count } do
      post stock_maintenance_adjust_url, params: { zaikonum: "9" }
    end
    assert_redirected_to menu_url
  end

  test "the order part edit screen has a button to the stock maintenance of the part" do
    row = Orderpart.create!(mno: @order.mno, sno: 10, partno: "A001", qty: 1, unitpd: 2500, irate: 1.0)
    get edit_orderpart_url(row)
    assert_select "a[href=?]", stock_maintenance_path(partno: "A001"), text: "この部品の在庫状況"
  end

  test "every screen and update needs a login" do
    delete session_url
    get stock_maintenance_url(partno: "A001")
    assert_redirected_to new_session_url(format: :html)
    %i[price hide reveal adjust standard forecast].each do |action|
      assert_no_difference -> { Stock.count + StockSetting.count } do
        post public_send("stock_maintenance_#{action}_url"), params: { partno: "A001", price: "1", zaikonum: "1", snum: "1", znum: "1" }
      end
      assert_redirected_to new_session_url(format: :html)
    end
    assert_equal 2500, @part.reload.newprice
  end
end
