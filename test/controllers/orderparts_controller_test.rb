require "test_helper"

# 注文部品詳細編集（orderparts#edit / update / destroy。旧 partsin2.asp）のテスト
class OrderpartsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @order = Order.create!(mno: 202610001, adlist_id: 1, shipname: "第一丸", country: "日本")
    # 1個あたりの重量は 2.0kg ÷ 計測単位2 = 1.0kg
    @part = Part.create!(pcode: "A001", jname: "和文の名称", ename: "English name", newprice: 1228,
                         weightkg: 2.0, munit: 2, sel_unit: "個")
    @orderpart = Orderpart.create!(mno: @order.mno, sno: 10, partno: "A001", itemno: "5", info: "元の備考",
                                   qty: 2, unitpd: 1228, irate: 0.8, totala: 2456, unitweight: 1.0, totalweight: 2.0)
  end

  def patch_field(**attrs)
    patch orderpart_url(@orderpart), params: { orderpart: attrs }
  end

  test "the sno on the order screen links to the edit screen" do
    get order_url(@order)
    assert_select "a[href=?]", edit_orderpart_path(@orderpart), text: "10"
  end

  test "a row without a sno still has a link to the edit screen" do
    @orderpart.update!(sno: nil)
    get order_url(@order)
    assert_select "a[href=?]", edit_orderpart_path(@orderpart), text: "-"
  end

  test "edit shows the part, the quantity table and the price calculation" do
    get edit_orderpart_url(@orderpart)
    assert_response :success
    assert_select "title", /注文部品詳細編集/
    assert_select "a[href=?]", part_path(@part), text: "A001"
    assert_select "td", text: "和文の名称"
    assert_select "td", text: "元の備考"
    assert_select "td", text: "個"
    assert_select "span", text: /取引No\. 202610001/
    # 数量2 × 単価1,228 = 2,456。掛け率0.8 → 単純計算 982、上 990、捨 980
    assert_select "td", text: "1,228", count: 2
    assert_select "td", text: "2,456"
    assert_select "td", text: "0.8"
    assert_select "td", text: "982"
    assert_select "td", text: "990"
    assert_select "td", text: "980"
    assert_select "a[href=?]", order_path(@order), text: "注文部品詳細へ戻る"
  end

  test "the name follows the country of the order" do
    @order.update!(country: "韓国")
    get edit_orderpart_url(@orderpart)
    assert_select "td", text: "English name"
    assert_select "td", text: "和文の名称", count: 0
  end

  test "edit falls back to the other name when one is empty" do
    @part.update!(jname: nil)
    get edit_orderpart_url(@orderpart)
    assert_select "td", text: "English name"
  end

  test "edit works for a part that is only in the kepart master" do
    kepart = Kepart.create!(pcode: "KE001", jname: "KE部品", ename: "KE part")
    row = Orderpart.create!(mno: @order.mno, sno: 20, partno: "KE001", qty: 1, unitpd: 10, irate: 1.0)
    get edit_orderpart_url(row)
    assert_response :success
    assert_select "a[href=?]", kepart_path(kepart), text: "KE001"
  end

  test "edit works for a part that is in no master" do
    row = Orderpart.create!(mno: @order.mno, sno: 20, partno: "NOMASTER", qty: 1, unitpd: 10, irate: 1.0)
    get edit_orderpart_url(row)
    assert_response :success
    assert_select "td", text: "NOMASTER"
  end

  test "edit has one form per item and a quantity grid from 0 to 99" do
    get edit_orderpart_url(@orderpart)
    %w[sno itemno info qty].each do |field|
      assert_select "form[action=?][method='post'] input[name='orderpart[#{field}]']", orderpart_path(@orderpart)
    end
    assert_select "form input[name=_method][value=patch]"
    assert_select "button[name='orderpart[qty]']", count: 100
    assert_select "button[name='orderpart[qty]'][value='0']"
    assert_select "button[name='orderpart[qty]'][value='99']"
    # 今の数量(2)の升目だけ強調する
    assert_select "button[name='orderpart[qty]'].bg-warning", count: 1
    assert_select "button[name='orderpart[qty]'][value='2'].bg-warning"
  end

  test "the loose quantity form is shown only for a part sold by a number of pieces" do
    get edit_orderpart_url(@orderpart)
    assert_select "input[name='orderpart[bqty]']", false

    @part.update!(sel_unit: "10")
    @orderpart.update!(bqty: 49)
    get edit_orderpart_url(@orderpart)
    assert_select "input[name='orderpart[bqty]'][value='49']"
    # バラ売単価 1,228 ÷ 10 = 123、バラ売数 49、バラ売数*単価 = 122.8*49 = 6,017
    assert_select "td", text: "123"
    assert_select "td", text: "49"
    assert_select "td", text: "6,017"
  end

  test "a stock row (^) is marked on the edit screen" do
    @orderpart.update!(kzaiko: "^")
    get edit_orderpart_url(@orderpart)
    assert_select "tr[style*='#00ffff']", minimum: 1
  end

  test "update changes the sno and stays on the edit screen with a message" do
    patch_field(sno: "25")
    assert_redirected_to edit_orderpart_url(@orderpart)
    assert_equal 303, response.status
    assert_equal "順を登録しました。", flash[:notice]
    assert_equal 25, @orderpart.reload.sno
    follow_redirect!
    assert_select ".alert-success", /順を登録しました。/
  end

  test "update changes the item no, the remark and the loose quantity" do
    patch_field(itemno: "9")
    patch_field(info: "新しい備考")
    patch_field(bqty: "12")
    @orderpart.reload
    assert_equal [ "9", "新しい備考", 12 ], [ @orderpart.itemno, @orderpart.info, @orderpart.bqty ]
  end

  test "update of the quantity recalculates the total amount and the total weight" do
    patch_field(qty: "7")
    @orderpart.reload
    assert_equal [ 7, 8596, 7.0 ], [ @orderpart.qty, @orderpart.totala, @orderpart.totalweight ]
    assert_equal "数量を登録しました。", flash[:notice]
  end

  test "update from the quantity grid" do
    patch orderpart_url(@orderpart), params: { orderpart: { qty: "0" } }
    assert_equal [ 0, 0, 0.0 ], @orderpart.reload.then { [ it.qty, it.totala, it.totalweight ] }
  end

  test "update refuses an invalid value with a message and keeps the edit screen" do
    patch_field(sno: "abc")
    assert_response :unprocessable_entity
    assert_select ".alert-error, .alert-danger, .alert", /順は -99999 から 99999 の整数で入力してください。/
    assert_select "title", /注文部品詳細編集/
    assert_equal 10, @orderpart.reload.sno
  end

  test "update refuses a negative quantity" do
    patch_field(qty: "-1")
    assert_response :unprocessable_entity
    assert_equal 2, @orderpart.reload.qty
  end

  test "update without any item is refused without an error page" do
    patch orderpart_url(@orderpart)
    assert_response :unprocessable_entity
    assert_select ".alert", /登録する項目がありません/
  end

  test "update ignores items that are not on the edit screen" do
    patch_field(unitpd: "1", partno: "HACK", mno: "999999999", info: "備考だけ")
    @orderpart.reload
    assert_equal [ 1228, "A001", 202610001, "備考だけ" ], [ @orderpart.unitpd, @orderpart.partno, @orderpart.mno, @orderpart.info ]
  end

  test "destroy deletes the part row physically and goes back to the order" do
    other = Orderpart.create!(mno: @order.mno, sno: 20, partno: "B002", qty: 1, unitpd: 10, irate: 1.0)
    delete orderpart_url(@orderpart)
    assert_redirected_to order_url(@order)
    assert_equal 303, response.status
    assert_equal "部品 A001 を削除しました。", flash[:notice]
    assert_equal 0, Orderpart.unscoped.where(id: @orderpart.id).count
    assert_equal 1, Orderpart.unscoped.where(id: other.id).count
  end

  test "the order screen no longer lists a deleted part row" do
    delete orderpart_url(@orderpart)
    get order_url(@order)
    assert_select "a[href=?]", edit_orderpart_path(@orderpart), false
  end

  test "the edit screen has a delete button that confirms with Turbo and uses DELETE" do
    get edit_orderpart_url(@orderpart)
    assert_select "form[action=?][data-turbo-confirm]", orderpart_path(@orderpart) do
      assert_select "input[name=_method][value=delete]"
      assert_select "button", text: "この部品を削除する"
    end
  end

  test "a deleted row cannot be edited" do
    delete orderpart_url(@orderpart)
    get edit_orderpart_url(@orderpart)
    assert_response :not_found
  end

  test "edit, update and destroy need a login" do
    delete session_url
    get edit_orderpart_url(@orderpart)
    assert_redirected_to new_session_url(format: :html)
    patch_field(sno: "99")
    assert_redirected_to new_session_url(format: :html)
    delete orderpart_url(@orderpart)
    assert_redirected_to new_session_url(format: :html)
    @orderpart.reload
    assert_equal 10, @orderpart.sno
  end
  # 注文部品詳細の一覧は、各グループの中を「順」順(同じ順は作成順)に並べる
  def listed_orderpart_ids
    css_select("a").map { |a| a["href"].to_s[%r{\A/orderparts/(\d+)/edit\z}, 1]&.to_i }.compact
  end

  def part_row(partno, sno)
    Part.find_or_create_by!(pcode: partno) { |part| part.jname = partno }
    Orderpart.create!(mno: @order.mno, sno: sno, partno: partno, qty: 1, unitpd: 10, irate: 1.0)
  end

  test "the order screen lists the part rows in sno order and ties in creation order" do
    r2 = part_row("A002", 5)
    r3 = part_row("A003", 20)
    r4 = part_row("A004", 5)
    get order_url(@order)
    assert_equal [ r2.id, r4.id, @orderpart.id, r3.id ], listed_orderpart_ids
  end

  test "a row without a sno is listed as sno 0" do
    r2 = part_row("A002", 5)
    r_nil = part_row("A005", nil)
    get order_url(@order)
    assert_equal [ r_nil.id, r2.id, @orderpart.id ], listed_orderpart_ids
  end

  test "a negative sno comes before a row without a sno, which counts as 0" do
    r_negative = part_row("A002", -10)
    r_nil = part_row("A005", nil)
    get order_url(@order)
    assert_equal [ r_negative.id, r_nil.id, @orderpart.id ], listed_orderpart_ids
  end

  test "changing the sno on the edit screen moves the row on the order screen" do
    r2 = part_row("A002", 5)
    r3 = part_row("A003", 20)
    get order_url(@order)
    assert_equal [ r2.id, @orderpart.id, r3.id ], listed_orderpart_ids

    patch orderpart_url(r3), params: { orderpart: { sno: "1" } }
    get order_url(@order)
    assert_equal [ r3.id, r2.id, @orderpart.id ], listed_orderpart_ids

    patch orderpart_url(@orderpart), params: { orderpart: { sno: "99" } }
    get order_url(@order)
    assert_equal [ r3.id, r2.id, @orderpart.id ], listed_orderpart_ids
  end

  test "the groups stay in place and each group is sorted by sno" do
    a_late = part_row("A002", 50)
    unknown_late = Orderpart.create!(mno: @order.mno, sno: 9, partno: "NOMASTER2", qty: 1, unitpd: 10, irate: 1.0)
    unknown_early = Orderpart.create!(mno: @order.mno, sno: 1, partno: "NOMASTER1", qty: 1, unitpd: 10, irate: 1.0)
    get order_url(@order)
    # A部品(部品台帳にある)が先、部品番号不明は後ろ。それぞれ順順
    assert_equal [ @orderpart.id, a_late.id, unknown_early.id, unknown_late.id ], listed_orderpart_ids
  end

  test "the part rows without a part number are also listed in sno order" do
    NOrderpart.create!(mno: @order.mno, sno: 30, partsname: "あとの部品名", qty: 1, tvalid: 1)
    NOrderpart.create!(mno: @order.mno, sno: 3, partsname: "さきの部品名", qty: 1, tvalid: 1)
    NOrderpart.create!(mno: @order.mno, sno: 3, partsname: "同じ順のあと", qty: 1, tvalid: 1)
    get order_url(@order)
    names = [ "さきの部品名", "同じ順のあと", "あとの部品名" ]
    positions = names.map { |name| response.body.index(name) }
    assert positions.all?, "部品名が表示されていない: #{positions.inspect}"
    assert_equal positions.sort, positions
  end
end
