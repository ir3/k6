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

  # --- 部品番号を入力して部品選択 ---

  test "show has the part number form" do
    get order_url(@order)
    assert_select "form[action='#{add_part_order_path(@order)}'][method='post']" do
      assert_select "input[name='partsno']"
      assert_select "input[type='submit'][value='部品番号を入力して部品選択']"
    end
  end

  test "add_part adds the row and goes back to the order with a message" do
    Part.create!(pcode: "A00401252", newprice: 140, weightkg: 0.5)
    assert_difference -> { Orderpart.where(mno: @order.mno).count }, 1 do
      post add_part_order_url(@order), params: { partsno: "a00401252" }
    end
    assert_redirected_to order_url(@order)
    follow_redirect!
    assert_select ".alert-success", /部品 A00401252 を追加しました。/
    assert_select ".alert-warning", false
  end

  test "add_part adds a stock row and a normal row for a part in the stock ledger" do
    Part.create!(pcode: "A00401252", newprice: 140)
    Stock.create!(partno: "A00401252", num: 3)
    assert_difference -> { Orderpart.where(mno: @order.mno).count }, 2 do
      post add_part_order_url(@order), params: { partsno: "A00401252" }
    end
    follow_redirect!
    assert_select ".alert-success", /在庫台帳にあるため、在庫分と通常の2行/
    assert_equal [ "^", nil ], Orderpart.where(mno: @order.mno).reorder(:id).pluck(:kzaiko)
  end

  test "add_part shows a warning when the new price is not set" do
    Part.create!(pcode: "A00401252", newprice: 0)
    post add_part_order_url(@order), params: { partsno: "A00401252" }
    follow_redirect!
    assert_select ".alert-success"
    assert_select ".alert-warning", /単価0/
  end

  test "add_part with an unknown number shows an error and adds nothing" do
    assert_no_difference -> { Orderpart.where(mno: @order.mno).count } do
      post add_part_order_url(@order), params: { partsno: "ZZZ999" }
    end
    assert_redirected_to order_url(@order)
    follow_redirect!
    assert_select ".alert-error", /見つかりません/
  end

  test "add_part with a blank number shows an error" do
    post add_part_order_url(@order), params: { partsno: "" }
    follow_redirect!
    assert_select ".alert-error", /入力してください/
  end

  # --- 複製（copy / keycopy / ocopy）の採番 ---

  # 複製元は「最後に開いた注文部品詳細」(session[:order_id])
  def open_as_copy_source
    get order_url(@order)
  end

  test "copy duplicates the order and its parts under the next management number" do
    travel_to Time.zone.local(2026, 10, 5, 12) do
      @order.update!(etype: "6L28HX", engno: "123", ono: "A-1", irate: 1.2, orderitem: "元の件名", memo: "元の内容")
      Orderpart.create!(mno: @order.mno, sno: 10, partno: "P1", qty: 2, unitpd: 500, irate: 1.2, totala: 1000)
      open_as_copy_source

      assert_difference -> { Order.reorder(nil).count }, 1 do
        post orders_copy_url
      end
      copy = Order.reorder(:id).last
      assert_redirected_to order_url(copy)
      assert_equal 202_610_002, copy.mno   # setup の注文が 202610001
      assert_equal "10002", copy.orderitem
      assert_equal [ 9001, "第一丸", "6L28HX", "123", "A-1", 1.2 ], [ copy.adlist_id, copy.shipname, copy.etype, copy.engno, copy.ono, copy.irate ]
      assert_nil copy.memo
      assert_nil copy.rdate
      assert_equal [ [ "P1", 2, 500 ] ], Orderpart.where(mno: copy.mno).pluck(:partno, :qty, :unitpd)
    end
  end

  test "keycopy duplicates only the company, ship and engine under the next management number" do
    travel_to Time.zone.local(2026, 10, 5, 12) do
      @order.update!(etype: "6L28HX", engno: "123", ono: "A-1", memo: "元の内容")
      open_as_copy_source

      post orders_keycopy_url
      copy = Order.reorder(:id).last
      assert_redirected_to order_url(copy)
      assert_equal [ 202_610_002, "10002" ], [ copy.mno, copy.orderitem ]
      assert_equal [ 9001, "第一丸", "6L28HX", "123", "A-1" ], [ copy.adlist_id, copy.shipname, copy.etype, copy.engno, copy.ono ]
      assert_nil copy.memo
      assert_empty Orderpart.where(mno: copy.mno)
    end
  end

  test "ocopy creates an empty order for the adlist under the next management number and opens its edit screen" do
    travel_to Time.zone.local(2026, 10, 5, 12) do
      post orders_ocopy_url, params: { adlist_id: "9002" }
      order = Order.reorder(:id).last
      assert_redirected_to edit_order_url(order)
      assert_equal [ 202_610_002, 9002 ], [ order.mno, order.adlist_id ]
    end
  end

  test "the order item of a copy always matches its management number even if numbers are taken while copying" do
    travel_to Time.zone.local(2026, 10, 5, 12) do
      open_as_copy_source
      # 採番のたびに、ほかの人が先に登録したことにして番号を進める（採番を2回呼ぶ実装だと件名とずれる）
      original = Order.method(:next_mno)
      Order.define_singleton_method(:next_mno) do |*args|
        number = original.call(*args)
        Order.create!(mno: number, adlist_id: 1) if number
        number
      end
      begin
        post orders_copy_url
        post orders_keycopy_url
      ensure
        Order.singleton_class.send(:remove_method, :next_mno)
        Order.define_singleton_method(:next_mno, original)
      end

      copies = Order.reorder(:id).select { |o| o.shipname == "第一丸" && o.mno != @order.mno }
      assert_equal 2, copies.size
      copies.each { |c| assert_equal c.mno.to_s[4, 5], c.orderitem, "mno=#{c.mno}" }
    end
  end

  test "copying twice in a row gives two different numbers" do
    travel_to Time.zone.local(2026, 10, 5, 12) do
      open_as_copy_source
      post orders_keycopy_url
      post orders_keycopy_url
      assert_equal [ 202_610_002, 202_610_003 ], Order.reorder(:mno).last(2).map(&:mno)
    end
  end

  test "copy, keycopy and ocopy are not fooled by an abnormal huge number in the data" do
    travel_to Time.zone.local(2026, 10, 5, 12) do
      Order.create!(mno: 405_024_078, adlist_id: 1)
      open_as_copy_source

      post orders_copy_url
      post orders_keycopy_url
      post orders_ocopy_url, params: { adlist_id: "9002" }
      assert_equal [ 202_610_002, 202_610_003, 202_610_004 ], Order.reorder(:id).last(3).map(&:mno)
    end
  end

  test "a copy continues from this month's numbers and starts again from 1 in a new month" do
    travel_to Time.zone.local(2026, 11, 2, 12) do
      open_as_copy_source
      post orders_keycopy_url
      assert_equal 202_611_001, Order.reorder(:id).last.mno
    end
  end

  test "copy, keycopy and ocopy refuse when the month has used up all 999 numbers, and add nothing" do
    travel_to Time.zone.local(2026, 10, 5, 12) do
      Order.create!(mno: 202_610_999, adlist_id: 1)
      open_as_copy_source
      Orderpart.create!(mno: @order.mno, sno: 10, partno: "P1", qty: 1)

      assert_no_difference [ -> { Order.reorder(nil).count }, -> { Orderpart.reorder(nil).count } ] do
        post orders_copy_url
        assert_redirected_to order_url(@order)
        post orders_keycopy_url
        assert_redirected_to order_url(@order)
        post orders_ocopy_url, params: { adlist_id: "9002" }
        assert_redirected_to orders_url
      end
      follow_redirect!
      assert_select ".alert-error", /上限\(999\)/
    end
  end

  test "copy and keycopy and ocopy need a login" do
    delete session_url
    assert_no_difference -> { Order.reorder(nil).count } do
      post orders_copy_url
      post orders_keycopy_url
      post orders_ocopy_url, params: { adlist_id: "9002" }
    end
  end

  # --- 取引台帳追加（新規取引登録） ---

  def new_order_params(overrides = {})
    { adlist_id: "9001", shipname: "新規丸", etype: "6L28HX", country: "日本",
      "rdate(1i)" => "2026", "rdate(2i)" => "11", "rdate(3i)" => "20" }.merge(overrides)
  end

  test "the nav bar has a new order button right after Menu on every screen" do
    [ menu_url, orders_url ].each do |url|
      get url
      links = css_select(".menu-horizontal li a").map { |a| [ a.text.strip, a["href"] ] }
      assert_equal [ [ "Home", welcom_index_path ], [ "Menu", menu_path ], [ "新規取引登録", new_order_path ] ], links.first(3), url
      assert_select ".menu-horizontal a.btn[href='#{new_order_path}']", text: "新規取引登録"
    end
  end

  test "new shows the shared form with the next management number and the title" do
    travel_to Time.zone.local(2026, 10, 5, 12) do
      Order.create!(mno: 202_610_012, adlist_id: 1)
      get new_order_url
    end
    assert_response :success
    assert_select "title", /取引台帳追加/
    assert_select "form[action='#{orders_path}'][method='post']" do
      assert_select "input[type='submit'][value='登録実行']"
      assert_select "input[name='expected_mno'][value='202610013']"
      assert_select "input[name='order[orderitem]'][value='10013']"
      assert_select "input[name='order[adlist_id]']"
    end
    assert_select "th", text: "管理番号"
    assert_select "td", text: "202610013"
    assert_select "td", text: "（取引先を選択してください）"
    assert_select "textarea[name='order[ncomment]']", text: /御社御下命後４日/
    assert_select "a.btn[href='#{orders_path}']", text: "登録しないで戻り"
    # 修正画面専用の更新日時は出さない
    assert_select "th", text: "更新日時", count: 0
  end

  test "new has the same fields as edit" do
    get new_order_url
    new_fields = css_select("form [name^='order[']").map { |e| e["name"] }.uniq.sort
    get edit_order_url(@order)
    edit_fields = css_select("form [name^='order[']").map { |e| e["name"] }.uniq.sort
    assert_equal edit_fields, new_fields
  end

  test "create registers the order with a freshly numbered management number" do
    travel_to Time.zone.local(2026, 10, 5, 12) do
      Order.create!(mno: 202_610_012, adlist_id: 1)
      assert_difference -> { Order.reorder(nil).count }, 1 do
        post orders_url, params: { expected_mno: "202610013", order: new_order_params }
      end
      order = Order.reorder(:id).last
      assert_redirected_to order_url(order)
      assert_equal 202_610_013, order.mno
      assert_equal "10013", order.orderitem
      assert_equal [ 9001, "新規丸", "6L28HX", "日本", Date.new(2026, 11, 20) ], [ order.adlist_id, order.shipname, order.etype, order.country, order.rdate ]
      assert_equal [ 1.0, 0.0, 1 ], [ order.irate, order.irate2, order.tvalid ]
      follow_redirect!
      assert_select ".alert-success", /取引台帳を登録しました。管理番号 202610013/
    end
  end

  test "after deleting the newest order the new order screen offers the same number again" do
    travel_to Time.zone.local(2026, 10, 5, 12) do
      Order.create!(mno: 202_610_012, adlist_id: 1)
      newest = Order.create!(mno: 202_610_013, adlist_id: 1)
      delete order_url(newest)
      get new_order_url
    end
    assert_select "input[name='expected_mno'][value='202610013']"
    assert_select "td", text: "202610013"
  end

  test "create keeps the order item the user typed" do
    travel_to Time.zone.local(2026, 10, 5, 12) do
      post orders_url, params: { order: new_order_params(orderitem: "ボルト 10本") }
      assert_equal "ボルト 10本", Order.reorder(:id).last.orderitem
    end
  end

  test "create ignores a management number sent from outside" do
    travel_to Time.zone.local(2026, 10, 5, 12) do
      # setup の注文が 202610001 なので、次は 202610002
      post orders_url, params: { order: new_order_params(mno: "999999999") }
      assert_equal 202_610_002, Order.reorder(:id).last.mno
    end
  end

  test "create needs an adlist and refuses a missing or unknown one" do
    travel_to Time.zone.local(2026, 10, 5, 12) do
      [ [ "", /取引先を選択してください/ ], [ "8888", /取引先が見つかりません/ ] ].each do |adlist_id, message|
        assert_no_difference -> { Order.reorder(nil).count } do
          post orders_url, params: { order: new_order_params(adlist_id: adlist_id, shipname: "入力保持") }
        end
        assert_response :unprocessable_entity
        assert_select ".alert-error", message
        assert_select "input[name='order[shipname]'][value='入力保持']"
      end
    end
  end

  test "create rejects an impossible delivery date" do
    assert_no_difference -> { Order.reorder(nil).count } do
      post orders_url, params: { order: new_order_params("rdate(2i)" => "2", "rdate(3i)" => "31") }
    end
    assert_response :unprocessable_entity
    assert_select ".alert-error", /納入期日が正しい日付ではありません/
  end

  test "create shows the new number instead of registering when someone else took the number" do
    travel_to Time.zone.local(2026, 10, 5, 12) do
      Order.create!(mno: 202_610_013, adlist_id: 1) # 画面を開いた後に、ほかの人が13番を登録した
      assert_no_difference -> { Order.reorder(nil).count } do
        post orders_url, params: { expected_mno: "202610013", order: new_order_params }
      end
      assert_response :unprocessable_entity
      assert_select ".alert-error", /202610013 から 202610014 に変わりました/
      assert_select "input[name='expected_mno'][value='202610014']"
      assert_select "td", text: "202610014"
      assert_select "input[name='order[shipname]'][value='新規丸']"
    end
  end

  test "create refuses when the month has used up all 999 numbers" do
    travel_to Time.zone.local(2026, 10, 5, 12) do
      Order.create!(mno: 202_610_999, adlist_id: 1)
      assert_no_difference -> { Order.reorder(nil).count } do
        post orders_url, params: { order: new_order_params }
      end
      assert_response :unprocessable_entity
      assert_select ".alert-error", /上限\(999\)/
    end
  end

  test "create is not fooled by an abnormal huge number in the data" do
    travel_to Time.zone.local(2026, 10, 5, 12) do
      Order.create!(mno: 405_024_078, adlist_id: 1)
      # setup の注文が 202610001 なので、次は 202610002（405024079 にはならない）
      post orders_url, params: { order: new_order_params }
      assert_equal 202_610_002, Order.reorder(:id).last.mno
    end
  end

  test "new and create need a login" do
    delete session_url
    get new_order_url
    assert_redirected_to new_session_url(format: :html)
    assert_no_difference -> { Order.reorder(nil).count } do
      post orders_url, params: { order: new_order_params }
    end
    assert_redirected_to new_session_url(format: :html)
  end

  # --- 部品番号が不明な分を部品名入力 ---

  test "show has the part name form in the rate row" do
    get order_url(@order)
    assert_select "form#order_part_name_form[action='#{add_part_name_order_path(@order)}'][method='post']"
    assert_select "input[name='partsname'][form='order_part_name_form']"
    assert_select "input[type='submit'][form='order_part_name_form'][value='部品番号が不明な分を部品名入力']"
    # 掛け率と同じ表の同じ行にある
    assert_select "table tr:has(input[name='partsname']):has(input[name='order[irate]'])"
  end

  test "add_part_name adds a no-part-number row and goes back to the order with a message" do
    assert_difference -> { NOrderpart.where(mno: @order.mno).count }, 1 do
      post add_part_name_order_url(@order), params: { partsname: "ﾎﾞﾙﾄ ﾅｯﾄ" }
    end
    assert_redirected_to order_url(@order)
    follow_redirect!
    assert_select ".alert-success", /部品名「ﾎﾞﾙﾄ ﾅｯﾄ」を部品番号なしで追加しました。/
  end

  test "a row added by name is shown as a valid row and counted in the other subtotal" do
    NOrderpart.create!(mno: @order.mno, sno: 10, partsname: "既存の行", qty: 2, rate: 0, unitpd: 1000, totala: 2000, tvalid: 1)
    post add_part_name_order_url(@order), params: { partsname: "追加した部品名" }
    follow_redirect!
    assert_response :success
    # 取り消し線(無効行)にならず、小計は既存の行だけ(追加行は単価0)
    assert_select "tr", text: /追加した部品名/
    assert_select "tr[style*='line-through']", text: /追加した部品名/, count: 0
    assert_select "tr", text: /その他小計.*2,000/m
  end

  test "add_part_name with a blank name shows an error and adds nothing" do
    assert_no_difference -> { NOrderpart.count } do
      post add_part_name_order_url(@order), params: { partsname: "  " }
    end
    follow_redirect!
    assert_select ".alert-error", /部品名を入力してください/
  end

  test "add_part_name needs a login" do
    delete session_url
    assert_no_difference -> { NOrderpart.count } do
      post add_part_name_order_url(@order), params: { partsname: "部品名" }
    end
    assert_redirected_to new_session_url(format: :html)
  end

  test "add_part needs a login" do
    Part.create!(pcode: "A00401252", newprice: 140)
    delete session_url
    assert_no_difference -> { Orderpart.count } do
      post add_part_order_url(@order), params: { partsno: "A00401252" }
    end
    assert_redirected_to new_session_url(format: :html)
  end
  # 注文の削除（asp/orderdel.asp 相当）。注文は論理削除、部品明細と部品番号なし明細は物理削除、
  # 在庫台帳は触らない。
  def setup_parts_and_stock
    other = Order.create!(mno: 202610002, adlist_id: 9001)
    Orderpart.create!(mno: @order.mno, sno: 10, partno: "X1")
    Orderpart.create!(mno: @order.mno, sno: 20, partno: "X2", deleted_at: Time.current)
    Orderpart.create!(mno: other.mno, sno: 10, partno: "Y1")
    NOrderpart.create!(mno: @order.mno, sno: 30, partsname: "名前だけの部品")
    Stock.create!(partno: "X1", num: 1, mno: @order.mno)
  end

  test "destroy soft-deletes the order and goes back to the list with a message" do
    delete order_url(@order)
    assert_redirected_to orders_url
    assert_equal 303, response.status
    assert_equal "取引 202610001 を削除しました。", flash[:notice]
    assert_nil Order.find_by(id: @order.id)
    assert_not_nil Order.unscoped.find(@order.id).deleted_at
  end

  test "destroy physically deletes the part rows of the order only" do
    setup_parts_and_stock
    delete order_url(@order)
    # 削除済みの行も含め、その注文のorderpartsは物理的に無くなる。別の注文のは残る
    assert_equal 0, Orderpart.unscoped.where(mno: 202610001).count
    assert_equal 1, Orderpart.unscoped.where(mno: 202610002).count
  end

  test "destroy also deletes the no-part-number rows of the order only" do
    setup_parts_and_stock
    NOrderpart.create!(mno: 202610002, sno: 10, partsname: "別の注文の部品名のみ")
    delete order_url(@order)
    assert_equal 0, NOrderpart.where(mno: 202610001).count
    assert_equal 1, NOrderpart.where(mno: 202610002).count
  end

  test "destroy leaves the stock rows as the old ASP did" do
    setup_parts_and_stock
    delete order_url(@order)
    assert_equal 1, Stock.where(mno: 202610001).count
  end

  test "a deleted order is gone from the list and a new order registers with its number again" do
    delete order_url(@order)
    get orders_url
    assert_select "table.list-table tbody tr", false
    assert_equal 202_610_001, Order.next_mno(Date.new(2026, 10, 5))
  end

  test "destroy of an already deleted order is not found" do
    delete order_url(@order)
    delete order_url(@order)
    assert_response :not_found
  end

  test "the order screen has a delete button that confirms with Turbo and uses DELETE" do
    get order_url(@order)
    assert_select "form[action=?][data-turbo-confirm]", order_path(@order) do
      assert_select "input[name=_method][value=delete]"
      assert_select "button", text: "台帳から削除"
    end
  end

  test "destroy needs a login and deletes nothing" do
    delete session_url
    delete order_url(@order)
    assert_redirected_to new_session_url(format: :html)
    assert_not_nil Order.find_by(id: @order.id)
  end
  # 取引台帳の並び順。初期値は降順（新しい取引が上）で、見出しの「取引No↕」で昇降を切り替える。
  def listed_mnos
    response.body.scan(/2026100\d\d/).uniq
  end

  def setup_three_orders
    Order.create!(mno: 202610002, adlist_id: 9001)
    Order.create!(mno: 202610003, adlist_id: 9001)
  end

  test "the order list is in descending order by default" do
    setup_three_orders
    travel_to Time.zone.local(2026, 10, 6, 12) do
      get orders_url
    end
    assert_equal %w[202610003 202610002 202610001], listed_mnos
  end

  test "the search result is in descending order by default" do
    setup_three_orders
    get orders_search_url(keyword: "202610")
    assert_equal %w[202610003 202610002 202610001], listed_mnos
  end

  test "the mno heading toggles the order and opening the list again returns to descending" do
    setup_three_orders
    travel_to Time.zone.local(2026, 10, 6, 12) do
      get orders_url
      get orders_url(mno_order: "DESC")
      assert_equal %w[202610001 202610002 202610003], listed_mnos
      get orders_url(mno_order: "ASC")
      assert_equal %w[202610003 202610002 202610001], listed_mnos
      get orders_url(mno_order: "DESC")
      assert_equal %w[202610001 202610002 202610003], listed_mnos
      get orders_url
      assert_equal %w[202610003 202610002 202610001], listed_mnos
    end
  end

  test "toggling without a remembered order starts from descending and goes ascending" do
    setup_three_orders
    get orders_search_url(keyword: "202610", mno_order: "x")
    assert_equal %w[202610001 202610002 202610003], listed_mnos
  end
end
