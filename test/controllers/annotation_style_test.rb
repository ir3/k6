require "test_helper"

# 画面の操作の説明や補足(注釈)は、旧ASPの .TB12 と同じ青い小さな文字(.TB12)で出す。
# メニュー画面の「.TB12.text-blue-600.text-xs」と同じ見た目にそろえている。
class AnnotationStyleTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    Registry.create!(country: "日本", countryid: "1")
    @adlist = Adlist.create!(no: "9001", company: "テスト海運株式会社", ruby: "てすと")
    @order = Order.create!(mno: 202610001, adlist_id: 9001, shipname: "第一丸", country: "日本")
    Part.create!(pcode: "A001", jname: "和名", newprice: 100, sel_unit: "10")
    @orderpart = Orderpart.create!(mno: @order.mno, sno: 10, partno: "A001", qty: 1, unitpd: 100, irate: 1.0)
  end

  test ".TB12 is blue 12px like the menu annotations" do
    css = File.read(Rails.root.join("app/assets/stylesheets/k.css"))
    rule = css[/\.TB12\s*\{([^}]*)\}/m, 1]
    assert rule, ".TB12 の定義がない"
    assert_match(/color:\s*#2563eb/i, rule)
    assert_match(/font-size:\s*12px/, rule)
  end

  test "the menu keeps its annotations in the same style" do
    get menu_url
    assert_select "span.TB12", minimum: 1
  end

  test "the order part edit screen explains the quantity and the loose quantity in the annotation style" do
    get edit_orderpart_url(@orderpart)
    assert_select "span.TB12", text: /数量をクリックして選択するか数字を入力してください/
    assert_select "p.TB12", text: /バラ指定の場合、例えば10個単位で1袋/
  end

  test "the new order screen explains the quick registration in the annotation style" do
    get new_order_url
    assert_select "span.TB12", text: /取引先と機番のみ入力で一旦登録すると/
  end

  test "the adlist picker explains itself in the annotation style" do
    get new_order_url
    assert_select "dialog p.TB12", text: /50音ボタンで取引先を選んでください/

    get adlists_picker_url(gyo: "あ")
    assert_select "p.TB12", text: /取引先の行をクリックすると/
    assert_select "p.text-base-content\\/60", false
  end

  test "the stock maintenance screen explains itself in the annotation style" do
    25.times { Stock.create!(partno: "A001", num: 1, irprice: 1) }
    get stock_maintenance_url(partno: "A001")
    assert_select "span.TB12", text: /入庫は＋、出庫は−/
    assert_select "span.TB12", text: /直近 21 件を表示しています（全 25 件）/
    assert_select "p.TB12", text: /在庫を引き当てた場合には、自動的に書き込まれます/

    Stock.create!(partno: "ONLYLEDGER", num: 3, irprice: 100)
    get stock_maintenance_url(partno: "ONLYLEDGER")
    assert_select "p.TB12", text: /部品台帳に登録がない/
  end

  test "the annotation style is not used on the table headers" do
    Stock.create!(partno: "A001", num: 1, irprice: 1)
    get stock_maintenance_url(partno: "A001")
    assert_select "th", minimum: 1
    assert_select "th.TB12, th .TB12", false
  end
end
