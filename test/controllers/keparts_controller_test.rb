require "test_helper"

# Ｂ部品メンテナンス（旧 hiteijomente.asp）。KE部品の詳細（/keparts/ID）がこの画面になる。
class KepartsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @kepart = Kepart.create!(pcode: "E001~", form: "6L28HX", size: "10x20", jname: "和文の名称", ename: "English name",
                             itemno: "7", weightkg: 1.5, munit: 2, newprice: 2500, comment: "元の備考")
  end

  test "the list headings are in Japanese" do
    get keparts_url
    headings = css_select("thead th").map { |th| th.text.strip }
    assert_equal %w[No. ID 部品コード 形式 寸法 和文名称 現行単価(円) 在庫 販売単位 重量(kg) 計測単位 ItemNo CORDNo 備考 更新日], headings
    # 一覧の最下部に、新規作成のボタンは置かない
    assert_select "a[href=?]", new_kepart_path, count: 0
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
end
