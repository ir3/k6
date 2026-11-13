require "test_helper"

# Ｂ部品メンテナンス（旧 hiteijomente.asp）。KE部品の詳細（/keparts/ID）がこの画面になる。
class KepartsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @kepart = Kepart.create!(pcode: "E001~", form: "6L28HX", size: "10x20", jname: "和文の名称", ename: "English name",
                             itemno: "7", weightkg: 1.5, munit: 2, newprice: 2500, comment: "元の備考")
  end

  test "the list headings are in Japanese and the first column is the form" do
    get keparts_url
    headings = css_select("thead th").map { |th| th.text.strip }
    assert_equal %w[No. ID 部品コード 形式 和文名称 現行単価(円) 在庫 販売単位 重量(kg) 計測単位 ItemNo CORDNo 備考 更新日], headings
    # 一覧の最下部に、新規作成のボタンは置かない
    assert_select "a[href=?]", new_kepart_path, count: 0
  end

  test "the list has the search and the new registration frames with their buttons" do
    get keparts_url(keyword: "E00")
    assert_select "form[action=?][method=get]", keparts_path do
      assert_select "input[name=keyword][value=?]", "E00"
      assert_select "input[type=submit][value=?]", "Ｂ部品検索"
    end
    assert_select "form[action=?][method=get]", new_kepart_path do
      assert_select "input[name=nparts][value=?]", "E00"
      assert_select "input[type=submit][value=?]", "新規Ｂ部品登録"
    end
    assert_match(/有効な検索条件：E00/, response.body)
  end

  test "without a tilde in the condition only the parts without a tilde are listed" do
    Kepart.create!(pcode: "E002", size: "S", form: "F2")
    get keparts_url
    assert_select "td a", text: "E002"
    assert_select "td a", text: "E001~", count: 0
    get keparts_url(keyword: "E00")
    assert_select "td a", text: "E002"
    assert_select "td a", text: "E001~", count: 0
  end

  test "with a tilde in the condition only the parts with a tilde are listed and the column is the size" do
    Kepart.create!(pcode: "E002", size: "S", form: "F2")
    get keparts_url(keyword: "E001~")
    assert_select "td a", text: "E001~"
    assert_select "td a", text: "E002", count: 0
    headings = css_select("thead th").map { |th| th.text.strip }
    assert_includes headings, "寸法"
    assert_not_includes headings, "形式"
    row = css_select("tbody tr").find { |tr| tr.css("td a").map(&:text).include?("E001~") }
    assert_includes row.css("td").map { |td| td.text.strip }, "10x20"
  end

  test "the search keeps the condition on the next page and takes full-width characters" do
    Kepart.create!(pcode: "FW123")
    get keparts_url(keyword: "ｆｗ１")
    assert_select "td a", text: "FW123"
    assert_match(/有効な検索条件：fw1/, response.body)
  end

  test "the new registration from a code that is a part makes the screen from the part" do
    Part.create!(pcode: "A0100", jname: "Ａ部品の和名", ename: "A PART NAME", sel_unit: "10", weightkg: 2.5, newprice: 3000)
    get new_kepart_url(nparts: "ａ0100")
    assert_response :success
    assert_select "title", /Ｂ部品新規登録/
    assert_select "input#kepart_pcode[value=?]", "A0100~"
    assert_select "input#kepart_jname[value=?]", "Ａ部品の和名"
    assert_select "input#kepart_ename[value=?]", "A PART NAME"
    assert_select "input#kepart_munit[value=?]", "10"
    assert_select "input#kepart_num[value=?]", "1"
    assert_select "input#kepart_weightkg[value=?]", "2.5"
    assert_select "input#kepart_newprice[value=?]", "3000"
    assert_select "input#kepart_itemno[value=?]", "0"
    assert_select "input[name=source][value=part]"
    assert_select "input[name=?][type=radio]", "kepart[ikubun]", count: 4
    assert_select "input#kepart_ikubun_1[checked]"
    assert_select "input[type=submit][value=?]", "新規Ｂ部品在庫登録"
  end

  test "the new registration from a code that is not a part makes the detail input screen" do
    get new_kepart_url(nparts: "zz-1")
    assert_response :success
    assert_select "title", /Ｂ部品詳細入力/
    assert_match(/Ａ部品台帳には、指定の部品コードはありません/, response.body)
    assert_select "input#kepart_pcode[value=?]", "ZZ-1"
    assert_select "input#kepart_munit[value=?]", "1"
    assert_select "input[name=source][value=scratch]"
    # 「名称」は「和文名称」になり、英文名称の入力枠がある
    headings = css_select("th").map { |th| th.text.strip }
    assert_includes headings, "和文名称"
    assert_includes headings, "英文名称"
    assert_not_includes headings, "名称"
    assert_select "input#kepart_jname"
    assert_select "input#kepart_ename[name=?]", "kepart[ename]"
    assert_match(/英文名称が空欄のときは、和文名称を英文名称にも登録します/, response.body)
    assert_select "input[type=submit][value=?]", "Ｂ部品登録"
  end

  test "the new registration from a code that is already a B part goes to the stock maintenance" do
    get new_kepart_url(nparts: "e001~")
    assert_redirected_to stockb_maintenance_url(partno: "E001~")
    assert_match(/Ｂ部品「E001~」は、すでにＢ部品台帳にあります/, flash[:notice])
  end

  test "the new registration without a code comes back to the list" do
    get new_kepart_url(nparts: "  ")
    assert_redirected_to keparts_url
    assert_equal "新規登録する部品コードを入力してください。", flash[:alert]
  end

  test "the registration from a part makes the part and a stock row and comes back to the list of its code" do
    assert_difference [ -> { Kepart.count }, -> { Stockb.count } ], 1 do
      post keparts_url, params: { source: "part", kepart: { pcode: "a0100~", size: "5x5", jname: "和名", ename: "ENG", munit: "10", num: "2",
                                                            weightkg: "2.5", newprice: "3000", itemno: "0", ikubun: "1" } }
    end
    assert_response :see_other
    assert_redirected_to keparts_url(keyword: "A0100~")
    assert_equal "Ｂ部品「A0100~」と、在庫台帳Ｂの1行を登録しました。", flash[:notice]
    assert_equal [ 0, 2 ], Stockb.find_by!(partno: "A0100~").then { |stock| [ stock.kind, stock.num ] }
  end

  test "the registration from nothing is kind 1 and an empty English name is the Japanese name" do
    post keparts_url, params: { source: "scratch", kepart: { pcode: "zz-1", jname: "名称のみ", munit: "1", num: "1", newprice: "100" } }
    assert_redirected_to keparts_url(keyword: "ZZ-1")
    kepart = Kepart.find_by!(pcode: "ZZ-1")
    assert_equal [ "名称のみ", "名称のみ" ], [ kepart.jname, kepart.ename ]
    assert_equal 1, Stockb.find_by!(partno: "ZZ-1").kind
  end

  test "the registration from nothing writes an entered English name" do
    post keparts_url, params: { source: "scratch", kepart: { pcode: "zz-2", jname: "和文の名称", ename: "ENGLISH NAME", munit: "1", num: "1" } }
    kepart = Kepart.find_by!(pcode: "ZZ-2")
    assert_equal [ "和文の名称", "ENGLISH NAME" ], [ kepart.jname, kepart.ename ]
  end

  test "a wrong registration from nothing keeps the typed English name" do
    post keparts_url, params: { source: "scratch", kepart: { pcode: "zz-3", jname: "和文", ename: "KEEP ME", newprice: "abc" } }
    assert_response :unprocessable_entity
    assert_select "input#kepart_jname[value=?]", "和文"
    assert_select "input#kepart_ename[value=?]", "KEEP ME"
  end

  test "a wrong registration shows the message and keeps what was typed" do
    assert_no_difference [ -> { Kepart.count }, -> { Stockb.count } ] do
      post keparts_url, params: { source: "part", kepart: { pcode: "N0200~", jname: "入力した名称", newprice: "abc", ikubun: "3" } }
    end
    assert_response :unprocessable_entity
    assert_select "p.text-error", text: /単価は 0 から 2000000000 の整数/
    assert_select "input#kepart_pcode[value=?]", "N0200~"
    assert_select "input#kepart_jname[value=?]", "入力した名称"
    assert_select "input#kepart_newprice[value=?]", "abc"
    assert_select "input#kepart_ikubun_3[checked]"
  end

  test "registering an existing code is refused" do
    assert_no_difference -> { Kepart.count } do
      post keparts_url, params: { source: "scratch", kepart: { pcode: "e001~" } }
    end
    assert_response :unprocessable_entity
    assert_select "p.text-error", text: /「E001~」は、すでにＢ部品台帳にあります/
  end

  test "someone who is not signed in cannot open or use the registration" do
    delete session_url
    get new_kepart_url(nparts: "ZZ-9")
    assert_redirected_to new_session_url(format: :html)
    assert_no_difference -> { Kepart.count } do
      post keparts_url, params: { source: "scratch", kepart: { pcode: "ZZ-9" } }
    end
    assert_redirected_to new_session_url(format: :html)
  end

  test "someone who is not signed in is sent to the login screen" do
    delete session_url
    get kepart_url(@kepart)
    assert_redirected_to new_session_url(format: :html)
    patch kepart_field_url(@kepart), params: { field: "comment", value: "変えられない" }
    assert_redirected_to new_session_url(format: :html)
    assert_equal "元の備考", @kepart.reload.comment
    delete kepart_url(@kepart)
    assert_redirected_to new_session_url(format: :html)
    assert Kepart.exists?(@kepart.id)
  end

  test "show is the B part maintenance screen with every item of the part" do
    get kepart_url(@kepart)
    assert_response :success
    assert_select "title", /Ｂ部品メンテナンス/
    assert_select "td", text: "E001~"
    { "寸法" => "10x20", "形式" => "6L28HX", "ItemNo" => "7", "和文名称" => "和文の名称", "英文名称" => "English name",
      "計測単位" => "2", "重量(kg)" => "1.5", "参考単価" => "2,500", "備考" => "元の備考" }.each do |label, value|
      row = css_select("tr").find { |tr| tr.at_css("th")&.text&.strip == label }
      assert row, label
      assert_equal value, row.css("td").first.text.strip, label
      # 項目名のセルは、見出しの行と同じ背景色（濃い青地に白文字）
      assert_includes row.at_css("th")["class"], "bg-primary", label
    end
  end

  test "every item has its own form with the button named like the old screen" do
    get kepart_url(@kepart)
    { size: "寸法登録", form: "形式登録", itemno: "ItemNo登録", jname: "和文名称変更登録", ename: "英文名称変更登録",
      munit: "計測単位登録", weightkg: "重量登録", newprice: "参考単価登録", comment: "備考登録" }.each do |field, button|
      assert_select "form[action=?][method=post]", kepart_field_path(@kepart) do
        assert_select "input[name=field][value=?]", field.to_s
        assert_select "input[type=submit][value=?]", button
      end
    end
    assert_select "form[action=?]", kepart_field_path(@kepart), count: 9
  end

  test "the stock reference button opens the B part stock maintenance" do
    get kepart_url(@kepart)
    assert_select "a[href=?]", stockb_maintenance_path(partno: "E001~"), text: "部品在庫参照"
  end

  test "the explanations use the blue annotation style" do
    get kepart_url(@kepart)
    assert_select "span.TB12", text: /取引毎に入力しますのでここでの入力は参考のみ/
  end

  test "a part with stock rows that have a trade number opens (it used to fail on mno2name)" do
    Stockb.create!(partno: "E001~", num: -3, irprice: 2500, okubun: 2, mno: 202611001)
    Stockb.create!(partno: "E001~", num: 5, irprice: 2500, ikubun: 1)
    get kepart_url(@kepart)
    assert_response :success
    assert_select "p.TB12", text: /在庫台帳Bの履歴（2 件）は、部品を削除しても消えません/
  end

  test "a part without stock rows says so" do
    get kepart_url(@kepart)
    assert_select "p.TB12", text: /在庫台帳Bの履歴はありません/
  end

  test "the stock maintenance's definition button opens this screen without an error" do
    Stockb.create!(partno: "E001~", num: -3, irprice: 2500, okubun: 2, mno: 202611001)
    get stockb_maintenance_url(partno: "E001~")
    assert_select "a[href=?]", kepart_path(@kepart), text: "部品定義参照"
    get kepart_url(@kepart)
    assert_response :success
  end

  test "an item is registered one at a time, and the screen comes back with a notice" do
    patch kepart_field_url(@kepart), params: { field: "comment", value: "新しい備考" }
    assert_response :see_other
    assert_redirected_to kepart_url(@kepart)
    assert_equal "備考を登録しました。", flash[:notice]
    @kepart.reload
    assert_equal "新しい備考", @kepart.comment
    # ほかの項目は変わらない
    assert_equal "10x20", @kepart.size
    assert_equal 2500, @kepart.newprice
  end

  test "every item can be registered" do
    { "size" => "20x30", "form" => "8L", "itemno" => "9", "jname" => "新和名", "ename" => "New name", "comment" => "備考2" }.each do |field, value|
      patch kepart_field_url(@kepart), params: { field: field, value: value }
      assert_equal value, @kepart.reload[field]
    end
    patch kepart_field_url(@kepart), params: { field: "munit", value: "5" }
    patch kepart_field_url(@kepart), params: { field: "weightkg", value: "0.75" }
    patch kepart_field_url(@kepart), params: { field: "newprice", value: "3900" }
    @kepart.reload
    assert_equal [ 5, 0.75, 3900 ], [ @kepart.munit, @kepart.weightkg, @kepart.newprice ]
  end

  test "a wrong value is refused with a message and the part is not changed" do
    patch kepart_field_url(@kepart), params: { field: "weightkg", value: "abc" }
    assert_redirected_to kepart_url(@kepart)
    assert_match(/重量は 0 から 1000000 の数で入力してください/, flash[:alert])
    assert_nil flash[:notice]
    assert_in_delta 1.5, @kepart.reload.weightkg
  end

  test "the part code cannot be changed from the screen" do
    patch kepart_field_url(@kepart), params: { field: "pcode", value: "HACKED~" }
    assert_redirected_to kepart_url(@kepart)
    assert_equal "登録する項目がありません。", flash[:alert]
    assert_equal "E001~", @kepart.reload.pcode
  end

  test "the delete button asks first and the delete removes the part but keeps its stock rows" do
    Stockb.create!(partno: "E001~", num: 5, irprice: 2500, ikubun: 1)
    get kepart_url(@kepart)
    assert_select "form[action=?][data-turbo-confirm=?]", kepart_path(@kepart),
                  "Ｂ部品「E001~」を削除します。元に戻せません。よろしいですか？" do
      assert_select "input[name=_method][value=delete]"
      assert_select "button, input[type=submit]", text: /この部品を削除する/
    end

    assert_difference -> { Kepart.count }, -1 do
      delete kepart_url(@kepart)
    end
    # Turbo の DELETE は 303 でないと、転送先にも DELETE を送ってしまう
    assert_response :see_other
    assert_redirected_to keparts_url
    assert_equal "Ｂ部品「E001~」を削除しました。", flash[:notice]
    assert_equal 1, Stockb.where(partno: "E001~").count
  end
  # 注文部品詳細の「部品番号を入力して部品選択」から来たとき（Ａ部品にもＢ部品にも無い部品番号）
  test "the registration from an order keeps the order, goes back to it and shows what it will do" do
    order = Order.create!(mno: 202611050, shipname: "第一丸")
    get new_kepart_url(nparts: "zz-ord-1", order_id: order.id)
    assert_response :success
    assert_select "input#kepart_pcode[value=?]", "ZZ-ORD-1"
    assert_select "input[type=hidden][name=order_id][value=?]", order.id.to_s
    assert_select "a[href=?]", order_path(order), text: "戻る"
    assert_select "span.TB12", text: /注文 202611050 に追加する部品を登録します/
  end

  test "the registration screen without an order has no hidden order and goes back to the list" do
    get new_kepart_url(nparts: "zz-ord-2")
    assert_select "input[name=order_id]", count: 0
    assert_select "a[href=?]", keparts_path, text: "戻る"
    assert_select "span.TB12", text: /に追加する部品を登録します/, count: 0
  end

  test "an order id that does not exist is ignored" do
    get new_kepart_url(nparts: "zz-ord-3", order_id: 0)
    assert_response :success
    assert_select "input[name=order_id]", count: 0
  end

  test "the registration from an order makes the B part and an order row with the entered quantity and price, but no stock row, and comes back to the order" do
    order = Order.create!(mno: 202611051, shipname: "第一丸")
    assert_difference [ -> { Kepart.count }, -> { Orderpart.where(mno: order.mno).count } ], 1 do
      assert_no_difference -> { Stockb.count } do
        post keparts_url, params: { source: "scratch", order_id: order.id,
                                    kepart: { pcode: "zz-ord-4", jname: "注文から登録", itemno: "5", munit: "1", num: "3", weightkg: "2", newprice: "1500" } }
      end
    end
    assert_response :see_other
    assert_redirected_to order_url(order)
    assert_equal "Ｂ部品「ZZ-ORD-4」を登録し、この注文の明細に追加しました（数量 3・単価 1500）。", flash[:notice]
    row = Orderpart.where(mno: order.mno).sole
    assert_equal [ "ZZ-ORD-4", "5", "2", 3, 1500, 4500, 2.0, 6.0 ],
                 [ row.partno, row.itemno, row.cordno, row.qty, row.unitpd, row.totala, row.unitweight, row.totalweight ]
    assert_equal [ 1500, 1500 ], Kepart.find_by!(pcode: "ZZ-ORD-4").then { |kepart| [ kepart.newprice, kepart.price ] }
  end

  test "the registration screen from an order has the amount column and no kind of receipt" do
    order = Order.create!(mno: 202611053, shipname: "第一丸")
    get new_kepart_url(nparts: "zz-ord-6", order_id: order.id)
    headings = css_select("th").map { |th| th.text.strip }
    assert_includes headings, "金額"
    assert_select "td", text: "自動計算"
    assert_select "input[name=?]", "kepart[ikubun]", count: 0
    assert_select "span.TB12", text: /Ｂ部品台帳とこの注文の明細に追加して、注文に戻ります/
    assert_select "p.TB12", text: /この注文の明細には、数量と単価をそのまま入れます（在庫台帳Ｂには登録しません）/
    # 注文から来ないときは、金額の列は無い
    get new_kepart_url(nparts: "zz-ord-7")
    assert_not_includes css_select("th").map { |th| th.text.strip }, "金額"
  end

  test "a wrong registration from an order keeps the order and adds nothing to it" do
    order = Order.create!(mno: 202611052, shipname: "第一丸")
    assert_no_difference [ -> { Kepart.count }, -> { Orderpart.where(mno: order.mno).count } ] do
      post keparts_url, params: { source: "scratch", order_id: order.id, kepart: { pcode: "zz-ord-5", jname: "名", newprice: "abc" } }
    end
    assert_response :unprocessable_entity
    assert_select "input[type=hidden][name=order_id][value=?]", order.id.to_s
    assert_select "a[href=?]", order_path(order), text: "戻る"
  end
end
