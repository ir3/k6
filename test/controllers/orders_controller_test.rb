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

  # 内容の更新は、注文部品詳細ではなく、取引台帳修正（旧 orderup.asp）で行う
  test "the content is changed on the order edit screen and the line breaks are kept" do
    @order.update!(memo: "元の内容")
    get edit_order_url(@order)
    assert_select "textarea[name='order[memo]']", text: /元の内容/
    patch order_url(@order), params: { order: { memo: "新しい内容\r\n2行目\r\n3行目" } }
    assert_redirected_to order_url(@order)
    assert_equal "新しい内容\r\n2行目\r\n3行目", @order.reload.memo
    follow_redirect!
    assert_select "td", text: /新しい内容\s*2行目\s*3行目/
  end

  test "the order detail shows the content but has no way to change it" do
    @order.update!(memo: "表示だけの内容")
    get order_url(@order)
    assert_select "td", text: "表示だけの内容"
    assert_select "textarea[name=memo]", count: 0
    patch "/orders/#{@order.id}/memo", params: { memo: "x" }
    assert_response :not_found
    assert_equal "表示だけの内容", @order.reload.memo
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

  test "add_part with a number that is not an A part goes to the B part registration and adds nothing yet" do
    assert_no_difference -> { Orderpart.where(mno: @order.mno).count } do
      post add_part_order_url(@order), params: { partsno: "zzz999" }
    end
    assert_redirected_to new_kepart_url(nparts: "ZZZ999", order_id: @order.id)
    assert_match(/部品番号「ZZZ999」は、Ａ部品にもＢ部品にもありません。Ｂ部品として登録してください/, flash[:notice])
  end

  test "add_part adds a B part as a row at its reference price when there is no A part with the number" do
    Kepart.create!(pcode: "E001~", jname: "Ｂの部品", newprice: 5000)
    assert_difference -> { Orderpart.where(mno: @order.mno).count }, 1 do
      post add_part_order_url(@order), params: { partsno: "e001~" }
    end
    assert_redirected_to order_url(@order)
    follow_redirect!
    assert_select ".alert-success", /Ｂ部品 E001~ を追加しました。単価は参考単価の 5000 円です（明細の「単価変更」で、取引ごとに直せます）/
    assert_select ".alert-warning", false
    assert_equal 5000, Orderpart.where(mno: @order.mno).sole.unitpd
  end

  test "add_part adds a B part without a reference price at price 0 and warns" do
    Kepart.create!(pcode: "E007~", newprice: 0)
    post add_part_order_url(@order), params: { partsno: "E007~" }
    follow_redirect!
    assert_select ".alert-success", /Ｂ部品 E007~ を追加しました。/
    assert_select ".alert-warning", /参考単価が未設定のため、単価0で追加しました/
    assert_equal 0, Orderpart.where(mno: @order.mno).sole.unitpd
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
  # 取引台帳追加は、取引先と機番だけの入力でも登録でき、空欄は同じ機番の直近の注文から埋める。
  def only_adlist_and_engno(engno = "ABC123", adlist_id: "9001")
    { adlist_id: adlist_id, engno: engno, country: "", ncomment: Order::DEFAULT_NCOMMENT,
      "rdate(1i)" => "2026", "rdate(2i)" => "11", "rdate(3i)" => "20" }
  end

  def make_latest_for_engno
    Order.create!(mno: 202_609_005, adlist_id: 9002, engno: "ABC123", shipname: "前の丸", etype: "6L28HX", country: "韓国",
                  tc: "TC-1", ono: "PO-77", irate: 0.8, irate2: 0.9, nebiki: 100, ncomment: "御社御下命後７日",
                  ndate: "2026/09/01", ldate: "2026/09/02", idate: "2026/09/03", odate: "2026/09/04", mdate: "2026/09/05",
                  tcondition: "2026/09/06", mitday: Date.new(2026, 9, 7), syuday: Date.new(2026, 9, 8), seiday: Date.new(2026, 9, 9),
                  memo: "前の内容", orderitem: "前の件名", rdate: Date.new(2026, 9, 30))
  end

  test "create with only the adlist and engno fills the blanks from the latest order of the same engno" do
    make_latest_for_engno
    travel_to Time.zone.local(2026, 10, 5, 12) do
      post orders_url, params: { order: only_adlist_and_engno }
    end
    order = Order.reorder(:id).last
    assert_redirected_to order_url(order)
    assert_equal [ "前の丸", "6L28HX", "韓国", "TC-1" ], [ order.shipname, order.etype, order.country, order.tc ]
    assert_equal [ 0.8, 0.9 ], [ order.irate, order.irate2 ]
    assert_equal "御社御下命後７日", order.ncomment
    # 取引先は入力どおり。引き継がないもの: 管理番号・納入期日・件名・内容・値引き・客先注文番号・各種日付
    assert_equal 0, order.nebiki.to_i
    assert order.ono.blank?, "客先注文番号は引き継がない: #{order.ono.inspect}"
    dates = %i[ndate ldate idate odate mdate tcondition mitday syuday seiday].map { |a| order[a] }
    assert dates.all?(&:blank?), "日付は引き継がない: #{dates.inspect}"
    assert_equal [ 9001, "ABC123", 202_610_002 ], [ order.adlist_id, order.engno, order.mno ]
    assert_equal Date.new(2026, 11, 20), order.rdate
    assert_equal order.mno.to_s[4, 5], order.orderitem
    assert_nil order.memo
    follow_redirect!
    assert_select ".alert-success", /機番 ABC123 の直近の取引 202609005 の情報で空欄を補いました/
  end

  test "create keeps what the user typed and fills only the blank fields" do
    make_latest_for_engno
    post orders_url, params: { order: only_adlist_and_engno.merge(shipname: "入力した丸", country: "日本", ncomment: "入力した納入コメント") }
    order = Order.reorder(:id).last
    assert_equal [ "入力した丸", "日本", "入力した納入コメント" ], [ order.shipname, order.country, order.ncomment ]
    # 入力しなかった項目は参照元から
    assert_equal [ "6L28HX", "TC-1" ], [ order.etype, order.tc ]
  end

  test "create takes the newest order of the engno and ignores deleted ones" do
    make_latest_for_engno
    Order.create!(mno: 202_609_006, adlist_id: 9002, engno: "ABC123", shipname: "さらに新しい丸")
    Order.create!(mno: 202_609_007, adlist_id: 9002, engno: "ABC123", shipname: "削除済みの丸", deleted_at: Time.current)
    post orders_url, params: { order: only_adlist_and_engno }
    assert_equal "さらに新しい丸", Order.reorder(:id).last.shipname
  end

  test "create with an engno that has no earlier order registers with the defaults" do
    post orders_url, params: { order: only_adlist_and_engno("NOPE999") }
    order = Order.reorder(:id).last
    assert_equal [ 9001, "NOPE999" ], [ order.adlist_id, order.engno ]
    assert_nil order.shipname
    # 船籍は先頭の国、納入コメントは既定の文言、掛け率は既定値
    assert_equal [ "日本", Order::DEFAULT_NCOMMENT, 1.0, 0.0 ], [ order.country, order.ncomment, order.irate, order.irate2 ]
    follow_redirect!
    assert_select ".alert-success", text: /取引台帳を登録しました。/
    assert_select ".alert-success", text: /空欄を補いました/, count: 0
  end

  test "create with a blank engno does not fill anything from other orders" do
    Order.create!(mno: 202_609_005, adlist_id: 9002, engno: "", shipname: "機番なしの丸")
    post orders_url, params: { order: only_adlist_and_engno("") }
    assert_nil Order.reorder(:id).last.shipname
  end

  test "the engno match ignores surrounding spaces" do
    make_latest_for_engno
    post orders_url, params: { order: only_adlist_and_engno(" ABC123 ") }
    assert_equal "前の丸", Order.reorder(:id).last.shipname
  end

  test "new offers an automatic blank country choice but edit does not" do
    get new_order_url
    assert_select "select[name='order[country]'] option[value='']", text: "（自動）"
    get edit_order_url(@order)
    assert_select "select[name='order[country]'] option[value='']", false
  end
  # 各種出力日（旧 partsin.asp の請求管理）。帳票出力履歴（order_logs）の日付を、8項目の表で出す
  def output_dates_row(label_text)
    th = css_select("th").find { |cell| cell.text.gsub(/\s+/, "") == label_text }
    assert th, "#{label_text} の見出しが無い"
    index = th.parent.css("th").index(th)
    th.parent.next_element.css("td")[index]
  end

  test "show lays the output dates out in one table of 8 items, with 未 for the ones not output yet" do
    get order_url(@order)
    assert_response :success
    labels = [ "見積依頼出力日", "初回見積出力日", "最新見積出力日", "受注/受注メモ出力日", "納品書出力日(請求要となった日)",
               "出荷案内出力日(請求要となった日)", "請求書出力日", "入金(確認)日" ]
    header_row = css_select("tr").find { |tr| tr.css("th").map { |th| th.text.gsub(/\s+/, "") } == labels }
    assert header_row, "8項目の見出しの行が無い"
    assert_equal [ "未" ] * 8, header_row.next_element.css("td").map { |td| td.text.strip }
  end

  test "show puts the dates of the output history under their items" do
    { 1 => Date.new(2026, 10, 16), 2 => Date.new(2026, 10, 17), 3 => Date.new(2026, 10, 18), 4 => Date.new(2026, 10, 19),
      5 => Date.new(2026, 10, 20), 6 => Date.new(2026, 10, 21), 7 => Date.new(2026, 10, 22) }.each do |kubun, date|
      OrderLog.create!(tvalid: 1, mno: @order.mno, kubun: kubun, datelog: date)
    end
    get order_url(@order)
    {
      "見積依頼出力日" => "2026/10/16", "初回見積出力日" => "2026/10/17", "最新見積出力日" => "2026/10/17",
      "受注/受注メモ出力日" => "2026/10/18", "納品書出力日(請求要となった日)" => "2026/10/22",
      "出荷案内出力日(請求要となった日)" => "2026/10/19", "請求書出力日" => "2026/10/20", "入金(確認)日" => "2026/10/21"
    }.each do |label, text|
      assert_equal text, output_dates_row(label).text.strip, label
    end
  end

  test "show marks a manually entered date" do
    OrderLog.create!(tvalid: 1, mno: @order.mno, kubun: 4, datelog: Date.new(2026, 10, 19))
    OrderLog.create!(tvalid: 1, mno: @order.mno, kubun: 104, datelog: Date.new(2026, 10, 25))
    get order_url(@order)
    cell = output_dates_row("出荷案内出力日(請求要となった日)")
    assert_equal "2026/10/25", cell.text.strip
    assert_equal "手動で入力した日付", cell.at_css("span")["title"]
    assert_nil output_dates_row("請求書出力日").at_css("span[title]")
  end

  test "show no longer prints the number of items under the delivery date" do
    @order.update!(pnum: 7)
    get order_url(@order)
    assert_equal "未", output_dates_row("納品書出力日(請求要となった日)").text.strip
  end
  # 日付を手で入れる欄（旧 partsin.asp → torihikikanri.asp）
  test "show has the check boxes only on the six items of the old screen, the date field and the button" do
    get order_url(@order)
    form = "order_output_dates_form"
    assert_select "form##{form}[method=post][action=?]", output_dates_order_path(@order)
    boxes = css_select("input[type=checkbox][name='kubun[]'][form=#{form}]")
    assert_equal %w[102 103 104 105 106 107], boxes.map { |box| box["value"] }.sort
    # 見積依頼・初回見積の欄には、旧ASPと同じく、チェックボックスが無い
    assert_nil output_dates_row("見積依頼出力日").at_css("input[type=checkbox]")
    assert_nil output_dates_row("初回見積出力日").at_css("input[type=checkbox]")
    assert_equal "102", output_dates_row("最新見積出力日").at_css("input[type=checkbox]")["value"]
    assert_equal "107", output_dates_row("納品書出力日(請求要となった日)").at_css("input[type=checkbox]")["value"]
    assert_equal "104", output_dates_row("出荷案内出力日(請求要となった日)").at_css("input[type=checkbox]")["value"]
    assert_select "input#output_inputday[type=date][form=#{form}][value=?]", Date.current.strftime("%Y-%m-%d")
    assert_select "input[type=submit][value=?][form=#{form}]", "日付更新"
  end

  test "the date update adds a manual record for each checked item and comes back to the order" do
    assert_difference -> { OrderLog.where(mno: @order.mno).count }, 2 do
      post output_dates_order_url(@order), params: { kubun: %w[104 106], inputday: "2026-11-20" }
    end
    assert_response :see_other
    assert_redirected_to order_url(@order)
    assert_equal "出荷案内出力日、入金(確認)日に、2026/11/20 を登録しました。", flash[:notice]
    assert_equal [ [ 104, Date.new(2026, 11, 20) ], [ 106, Date.new(2026, 11, 20) ] ],
                 OrderLog.where(mno: @order.mno).order(:kubun).pluck(:kubun, :datelog)

    follow_redirect!
    cell = output_dates_row("出荷案内出力日(請求要となった日)")
    assert_equal "2026/11/20", cell.text.strip
    assert_equal "手動で入力した日付", cell.at_css("span")["title"]
    assert_equal "2026/11/20", output_dates_row("入金(確認)日").text.strip
  end

  test "the date update with nothing checked or a wrong date is refused with a message and adds nothing" do
    assert_no_difference -> { OrderLog.count } do
      post output_dates_order_url(@order), params: { inputday: "2026-11-20" }
      assert_redirected_to order_url(@order)
      assert_equal "日付を登録する項目にチェックを入れてください。", flash[:alert]

      post output_dates_order_url(@order), params: { kubun: %w[105], inputday: "" }
      assert_match(/日付を入力してください/, flash[:alert])

      post output_dates_order_url(@order), params: { kubun: %w[105], inputday: "2026-02-30" }
      assert_match(/日付を入力してください/, flash[:alert])
    end
  end

  test "the date update takes only the kinds of the six check boxes" do
    post output_dates_order_url(@order), params: { kubun: %w[1 2 101 105], inputday: "2026-11-20" }
    assert_equal [ 105 ], OrderLog.where(mno: @order.mno).pluck(:kubun)
  end

  test "the date update of an order that does not exist is not found and someone who is not signed in cannot use it" do
    post output_dates_order_url(id: 0), params: { kubun: %w[105], inputday: "2026-11-20" }
    assert_response :not_found
    delete session_url
    post output_dates_order_url(@order), params: { kubun: %w[105], inputday: "2026-11-20" }
    assert_redirected_to new_session_url(format: :html)
    assert_equal 0, OrderLog.where(mno: @order.mno).count
  end
  test "show gives the headings of the output dates their own (green) class" do
    get order_url(@order)
    th = css_select("th").find { |cell| cell.text.strip == "見積依頼出力日" }
    assert_includes th["class"], "output-dates-head"
    # 8項目すべての見出しが同じ色。ほかの項目名（取引管理No. など）には付かない
    assert_equal 8, css_select("th.output-dates-head").size
    assert_not_includes css_select("th").find { |cell| cell.text.strip == "取引管理No." }["class"], "output-dates-head"
  end
  # 並び替え後表示の部品コードのリンク（注文部品詳細と同じ）
  test "the sorted view links the part codes of A parts and B parts to their detail edit screens" do
    Part.create!(pcode: "SA001", jname: "Ａの部品", newprice: 100)
    Kepart.create!(pcode: "SB001~", jname: "Ｂの部品", newprice: 100)
    a_row = Orderpart.create!(mno: @order.mno, sno: 10, partno: "SA001", qty: 1, unitpd: 100, irate: 1.0)
    b_row = Orderpart.create!(mno: @order.mno, sno: 20, partno: "SB001~", qty: 1, unitpd: 100, irate: 1.0)
    get sorted_order_url(@order)
    assert_response :success
    links = css_select("td a").to_h { |a| [ a.text.strip, a["href"] ] }
    assert_equal edit_orderpart_path(b_row), links["SB001~"]
    assert_equal edit_orderpart_path(a_row), links["SA001"]
  end
  # 小計の行の背景色（A部品小計・B部品小計は薄黄緑。そのほかは、これまでの青みがかった色）
  def summary_row_background(label)
    row = css_select("tr").find { |tr| tr.at_css("td")&.text&.strip == label }
    assert row, "#{label} の行が無い"
    row.at_css("td")["style"][/background-color:\s*(#\h+)/i, 1]&.downcase
  end

  test "the A part subtotal and the B part subtotal rows are pale yellow-green and the other rows keep their color" do
    Part.create!(pcode: "SUB-A", jname: "Ａ", newprice: 100)
    Kepart.create!(pcode: "SUB-B~", jname: "Ｂ", newprice: 200)
    Orderpart.create!(mno: @order.mno, sno: 10, partno: "SUB-A", qty: 1, unitpd: 100, irate: 1.0)
    Orderpart.create!(mno: @order.mno, sno: 20, partno: "SUB-B~", qty: 1, unitpd: 200, irate: 1.0)
    NOrderpart.create!(mno: @order.mno, sno: 30, partsname: "その他の部品", qty: 1, unitpd: 300, tvalid: 1)
    Orderpart.create!(mno: @order.mno, sno: 40, partno: "NO-MASTER", qty: 1, unitpd: 400, irate: 1.0)
    get order_url(@order)
    assert_response :success
    assert_equal "#e2efbd", summary_row_background("A部品小計")
    assert_equal "#e2efbd", summary_row_background("B部品小計")
    # そのほかの小計・合計は、これまでの色
    assert_equal "#c8dce8", summary_row_background("その他小計")
    assert_equal "#c8dce8", summary_row_background("部品番号不明小計")
    assert_equal "#c8dce8", summary_row_background("合計")
  end

  test "all the cells of the A part subtotal row have the same background" do
    Part.create!(pcode: "SUB-A2", jname: "Ａ", newprice: 100)
    Orderpart.create!(mno: @order.mno, sno: 10, partno: "SUB-A2", qty: 1, unitpd: 100, irate: 1.0)
    get order_url(@order)
    row = css_select("tr").find { |tr| tr.at_css("td")&.text&.strip == "A部品小計" }
    colors = row.css("td").map { |td| td["style"].to_s[/background-color:\s*(#\h+)/i, 1] }
    assert_equal [ "#e2efbd" ], colors.uniq
  end
  test "the order detail has the button to the sorted view without the temporary mark" do
    get order_url(@order)
    assert_select "a[href=?]", sorted_order_path(@order), text: "並び替え後表示"
    assert_select "a", text: /並び替え後表示.*仮/, count: 0
  end
  # 注釈の入力枠と更新ボタン（旧 partsin.asp の「注釈」の行・旧 updcom.asp）。内容は、注文部品詳細では表示だけ
  test "show has the annotation form with its update button, and the content is only shown" do
    @order.update!(memo: "1行目\n2行目")
    OrderAnnotation.create!(tvalid: 1, mno: @order.mno, comment: "清水仕様")
    get order_url(@order)
    assert_response :success
    assert_select "form[action=?][method=post]", annotation_order_path(@order) do
      assert_select "input[name=_method][value=patch]"
      assert_select "input#order_annotation[name=comment][value=?]", "清水仕様"
      assert_select "input[type=submit][value=?]", "更新"
    end
    # 内容は、表に表示するだけ（入力枠も、内容の更新ボタンも無い。更新は、取引台帳修正で行う）
    assert_select "textarea#order_memo", count: 0
    assert_select "form[action$=?]", "/memo", count: 0
    labels = css_select("th").map { |th| th.text.strip }
    assert_includes labels, "内容"
    assert_includes labels, "注釈"
    assert_select "td", text: /1行目\s*2行目/
  end

  test "show has an empty annotation field for an order that has no annotation" do
    get order_url(@order)
    assert_select "input#order_annotation[name=comment]:not([value])"
  end

  test "the annotation form adds the annotation and comes back to the order with a message" do
    assert_difference -> { OrderAnnotation.where(mno: @order.mno).count }, 1 do
      patch annotation_order_url(@order), params: { comment: "E40611100にて出荷" }
    end
    assert_response :see_other
    assert_redirected_to order_url(@order)
    assert_equal "注釈を更新しました。", flash[:notice]
    follow_redirect!
    assert_select "input#order_annotation[value=?]", "E40611100にて出荷"
  end

  test "the annotation form updates the existing annotation and clears it with an empty value" do
    OrderAnnotation.create!(tvalid: 1, mno: @order.mno, comment: "元の注釈")
    assert_no_difference -> { OrderAnnotation.count } do
      patch annotation_order_url(@order), params: { comment: "新しい注釈" }
    end
    assert_equal [ "新しい注釈" ], OrderAnnotation.where(mno: @order.mno).pluck(:comment)
    patch annotation_order_url(@order), params: { comment: "" }
    assert_equal [ "" ], OrderAnnotation.where(mno: @order.mno).pluck(:comment)
  end

  test "a too long annotation shows the message on the order and changes nothing" do
    patch annotation_order_url(@order), params: { comment: "あ" * 256 }
    assert_redirected_to order_url(@order)
    assert_equal "注釈は 255 文字以内で入力してください。", flash[:alert]
    assert_equal 0, OrderAnnotation.where(mno: @order.mno).count
  end

  test "the annotation update needs a signed in user and an existing order" do
    patch annotation_order_url(id: 0), params: { comment: "x" }
    assert_response :not_found
    delete session_url
    patch annotation_order_url(@order), params: { comment: "x" }
    assert_redirected_to new_session_url(format: :html)
    assert_equal 0, OrderAnnotation.where(mno: @order.mno).count
  end
  # 取引台帳の一覧の項目名は、注文部品詳細と同じ「内容」（以前は、全件一覧と検索結果が「Memo」だった）
  test "the order lists call the memo column 内容, like the order detail" do
    { "取引台帳" => orders_url, "検索結果" => orders_search_url(keyword: "202610"), "全件一覧" => orders_alllist_url }.each do |name, url|
      get url
      assert_response :success, name
      headings = css_select("th").map { |th| th.text.strip }
      assert_includes headings, "内容", name
      assert_not_includes headings, "Memo", name
    end
    get order_url(@order)
    assert_includes css_select("th").map { |th| th.text.strip }, "内容"
  end
  test "the content search shows 内容検索 as the search condition, and finds the orders by their content" do
    @order.update!(memo: "清水仕様のノート")
    Order.create!(mno: 202610099, memo: "別の内容")
    post orders_search_url, params: { keyword: "清水仕様", keykind: "memo" }
    follow_redirect! while response.redirect?
    assert_response :success
    assert_select "span", text: /内容検索: 清水仕様/
    assert_select "span", text: /メモ検索/, count: 0
    assert_equal [ @order.mno.to_s ], css_select("tbody tr").flat_map { |tr| tr.css("td a").map { |a| a.text.strip } }.select { |t| t.match?(/\A\d{9}\z/) }.uniq
  end
end
