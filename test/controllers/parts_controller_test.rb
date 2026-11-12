require "test_helper"

# Ａ部品メンテナンス（旧 partsmente.asp）。部品台帳の詳細（/parts/ID）がこの画面になる。
class PartsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @part = Part.create!(pcode: "A0001", form: "6L28HX", jname: "和文の名称", ename: "English name", sel_unit: "10",
                         weightkg: 1.5, munit: 2, newprice: 2500, price: 1000, comment: "元の備考")
  end

  test "someone who is not signed in is sent to the login screen" do
    delete session_url
    get part_url(@part)
    assert_redirected_to new_session_url(format: :html)
    patch part_field_url(@part), params: { field: "comment", value: "変えられない" }
    assert_redirected_to new_session_url(format: :html)
    post part_duplicate_url(@part), params: { new_code: "A0002" }
    assert_redirected_to new_session_url(format: :html)
    delete part_url(@part)
    assert_redirected_to new_session_url(format: :html)
    assert_equal "元の備考", @part.reload.comment
    assert_equal 1, Part.where(pcode: %w[A0001 A0002]).count
  end

  test "show is the A part maintenance screen with every item of the part" do
    get part_url(@part)
    assert_response :success
    assert_select "title", /Ａ部品メンテナンス/
    assert_select "td", text: "A0001"
    { "形式" => "6L28HX", "和文名称" => "和文の名称", "英文名称" => "English name", "販売単位" => "10",
      "重量(kg)" => "1.5", "計測単位" => "2", "新単価" => "2,500", "現行単価" => "1,000", "備考" => "元の備考" }.each do |label, value|
      row = css_select("tr").find { |tr| tr.at_css("th")&.text&.strip == label }
      assert row, label
      assert_equal value, row.css("td").first.text.strip, label
      assert_includes row.at_css("th")["class"], "bg-primary", label
    end
  end

  test "every item has its own form with the button named like the old screen" do
    get part_url(@part)
    { form: "形式変更登録", jname: "和文名称変更登録", ename: "英文名称変更登録", sel_unit: "販売単位変更登録",
      weightkg: "重量変更登録", newprice: "新単価変更", price: "旧単価登録", comment: "備考変更登録",
      opartno: "旧部品番号を登録" }.each do |field, button|
      assert_select "form[action=?][method=post]", part_field_path(@part) do
        assert_select "input[name=field][value=?]", field.to_s
        assert_select "input[type=submit][value=?]", button
      end
    end
    assert_select "form[action=?]", part_field_path(@part), count: 9
    # 計測単位は、旧ASPと同じく表示だけ
    assert_select "input[name=field][value=munit]", count: 0
  end

  test "the old part number from the stock setting is shown" do
    StockSetting.create!(partno: "A0001", opartno: "OLD-9")
    get part_url(@part)
    row = css_select("tr").find { |tr| tr.at_css("th")&.text&.strip == "旧部品番号" }
    assert_equal "OLD-9", row.css("td").first.text.strip
    assert_select "input#part_opartno[value=?]", "OLD-9"
  end

  test "the stock reference button opens the stock maintenance and the notes use the blue annotation style" do
    get part_url(@part)
    assert_select "a[href=?]", stock_maintenance_path(partno: "A0001"), text: "部品在庫参照"
    assert_select "span.TB12", text: /掛け率の掛からない単価を入力してください/
  end

  test "a part with stock rows that have a trade number opens (the old screen failed on mno2name)" do
    Stock.create!(partno: "A0001", num: -3, irprice: 2500, okubun: 2, mno: 202611001)
    Stock.create!(partno: "A0001", num: 5, irprice: 2500, ikubun: 1)
    get part_url(@part)
    assert_response :success
    assert_select "p.TB12", text: /在庫台帳の履歴（2 件）は、部品を削除しても消えません/
  end

  test "a part without stock rows says so" do
    get part_url(@part)
    assert_select "p.TB12", text: /在庫台帳の履歴はありません/
  end

  test "an item is registered one at a time, and the screen comes back with a notice" do
    patch part_field_url(@part), params: { field: "comment", value: "新しい備考" }
    assert_response :see_other
    assert_redirected_to part_url(@part)
    assert_equal "備考を登録しました。", flash[:notice]
    @part.reload
    assert_equal "新しい備考", @part.comment
    assert_equal [ "6L28HX", 2500, 1000 ], [ @part.form, @part.newprice, @part.price ]
  end

  test "a wrong value is refused with a message and the part is not changed" do
    patch part_field_url(@part), params: { field: "newprice", value: "abc" }
    assert_redirected_to part_url(@part)
    assert_match(/新単価は 0 から 2000000000 の整数で入力してください/, flash[:alert])
    assert_nil flash[:notice]
    assert_equal 2500, @part.reload.newprice
  end

  test "the part code cannot be changed from the screen" do
    patch part_field_url(@part), params: { field: "pcode", value: "HACKED" }
    assert_equal "登録する項目がありません。", flash[:alert]
    assert_equal "A0001", @part.reload.pcode
  end

  test "the duplicate button makes a new part and opens it" do
    assert_difference -> { Part.count }, 1 do
      post part_duplicate_url(@part), params: { new_code: "a0002" }
    end
    copy = Part.find_by!(pcode: "A0002")
    assert_response :see_other
    assert_redirected_to part_url(copy)
    assert_equal "新しい部品「A0002」を作りました。", flash[:notice]
    assert_equal [ "和文の名称", 2500 ], [ copy.jname, copy.newprice ]
  end

  test "the duplicate with the same code is refused with a message" do
    assert_no_difference -> { Part.count } do
      post part_duplicate_url(@part), params: { new_code: "A0001" }
    end
    assert_redirected_to part_url(@part)
    assert_match(/元の部品と同じ部品コードです/, flash[:alert])
  end

  test "the delete button asks first and the delete removes the part but keeps its stock rows" do
    Stock.create!(partno: "A0001", num: 5, irprice: 2500, ikubun: 1)
    get part_url(@part)
    assert_select "form[action=?][data-turbo-confirm=?]", part_path(@part),
                  "Ａ部品「A0001」を削除します。元に戻せません。よろしいですか？" do
      assert_select "input[name=_method][value=delete]"
    end

    assert_difference -> { Part.count }, -1 do
      delete part_url(@part)
    end
    # Turbo の DELETE は 303 でないと、転送先にも DELETE を送ってしまう
    assert_response :see_other
    assert_redirected_to parts_url
    assert_equal "Ａ部品「A0001」を削除しました。", flash[:notice]
    assert_equal 1, Stock.where(partno: "A0001").count
  end

  test "the list headings are in Japanese" do
    get parts_url
    headings = css_select("thead th").map { |th| th.text.strip }
    assert_equal %w[No. ID 部品コード 形式 和文名称 英文名称 在庫 販売単位 現行単価 新単価(円) 重量(kg) 計測単位 ItemNo CORDNo 備考 更新日 登録日], headings
  end

  test "the list has the search and the new registration frames with their buttons" do
    get parts_url(keyword: "A00")
    assert_select "form[action=?][method=get]", parts_path do
      assert_select "input[name=keyword][value=?]", "A00"
      assert_select "input[type=submit][value=?]", "Ａ部品検索"
    end
    assert_select "form[action=?][method=get]", new_part_path do
      assert_select "input[name=nparts][value=?]", "A00"
      assert_select "input[type=submit][value=?]", "新規Ａ部品登録"
    end
    assert_match(/有効な検索条件：A00/, response.body)
    # 一覧の最下部に、新規作成のボタン（リンク）は置かない。新規登録は上部の枠から行う
    assert_select "a[href=?]", new_part_path, count: 0
    assert_select "a.btn", text: "新規作成", count: 0
  end

  test "the search finds parts by a part of the code and keeps the condition" do
    Part.create!(pcode: "B00X1")
    Part.create!(pcode: "C9999")
    get parts_url(keyword: "００X")
    assert_select "td a", text: "B00X1"
    assert_select "td a", text: "C9999", count: 0
    assert_select "td a", text: "A0001", count: 0
    assert_select "p", text: /旧部品番号.*を検出しました/, count: 0
  end

  test "the search finds the new part by an old part number and says so" do
    StockSetting.create!(partno: "A0001", opartno: "OLD-77")
    Part.create!(pcode: "ZZZ99")
    get parts_url(keyword: "old-77")
    assert_select "p", text: "旧部品番号:old-77 を検出しました。対応する新部品番号のデータを出力します。"
    assert_select "td a", text: "A0001"
    assert_select "td a", text: "ZZZ99", count: 0
  end

  test "the new registration screen takes the code from the frame" do
    get new_part_url(nparts: "ｎｅｗ-1")
    assert_response :success
    assert_select "title", /Ａ部品詳細入力/
    assert_select "input#part_pcode[value=?]", "NEW-1"
    assert_select "input#part_munit[value=?]", "1"
    assert_select "form[action=?][method=post]", parts_path do
      %w[pcode form jname ename munit weightkg newprice].each { |item| assert_select "input[name=?]", "part[#{item}]" }
      assert_select "input[type=submit][value=?]", "Ａ部品登録"
    end
  end

  test "the registration makes the part and comes back to the list of its code" do
    assert_difference -> { Part.count }, 1 do
      post parts_url, params: { part: { pcode: "n0100", form: "6L", jname: "登録部品", ename: "REG", munit: "1", weightkg: "0.5", newprice: "1200" } }
    end
    assert_response :see_other
    assert_redirected_to parts_url(keyword: "N0100")
    assert_equal "Ａ部品「N0100」を登録しました。", flash[:notice]
    part = Part.find_by!(pcode: "N0100")
    assert_equal [ "登録部品", 1200, 1200 ], [ part.jname, part.newprice, part.price ]
  end

  test "a wrong registration shows the message and keeps what was typed" do
    assert_no_difference -> { Part.count } do
      post parts_url, params: { part: { pcode: "N0200", jname: "入力した名称", newprice: "abc" } }
    end
    assert_response :unprocessable_entity
    assert_select "p.text-error", text: /単価は 0 から 2000000000 の整数/
    assert_select "input#part_pcode[value=?]", "N0200"
    assert_select "input#part_jname[value=?]", "入力した名称"
    assert_select "input#part_newprice[value=?]", "abc"
  end

  test "registering an existing code is refused" do
    assert_no_difference -> { Part.count } do
      post parts_url, params: { part: { pcode: "a0001" } }
    end
    assert_response :unprocessable_entity
    assert_select "p.text-error", text: /「A0001」は、すでにＡ部品台帳にあります/
  end

  test "someone who is not signed in cannot open or use the registration" do
    delete session_url
    get new_part_url
    assert_redirected_to new_session_url(format: :html)
    assert_no_difference -> { Part.count } do
      post parts_url, params: { part: { pcode: "N0300" } }
    end
    assert_redirected_to new_session_url(format: :html)
  end

  test "the old search by SQL string is gone (the list searches with GET /parts?keyword=)" do
    post "/parts/search", params: { keyword: "A0001' OR '1'='1" }
    assert_response :not_found
  end

  test "the list links the part code to this screen" do
    get parts_url
    assert_select "a[href=?]", part_path(@part), text: "A0001"
  end
end
