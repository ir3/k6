require "test_helper"

# Ｂ部品在庫表示（旧 hzaikolist.asp → hzaikosel.asp）のテスト
class StockbsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @k1 = Kepart.create!(pcode: "E001", form: "6L28HX", size: "10x20", jname: "和名1", ename: "NAME 1", newprice: 12_000,
                         sel_unit: "10", weightkg: 0.235, munit: 2)
    @k2 = Kepart.create!(pcode: "E002", form: "6M31", jname: "和名2", ename: "NAME 2", newprice: 500)
    @kt = Kepart.create!(pcode: "E500~", form: "型式T", size: "50A", jname: "和名T", ename: "NAME T", newprice: 80)
    Stockb.create!(partno: "E001", num: 10, novalid: 0)
    Stockb.create!(partno: "E001", num: -3, novalid: 0)
    Stockb.create!(partno: "E002", num: 4, novalid: 0)
    Stockb.create!(partno: "E500~", num: 6, novalid: 0)
  end

  def row_for(pcode)
    css_select("tbody tr").find { |tr| tr.at_css("td")&.text&.strip == pcode }
  end

  test "someone who is not signed in is sent to the login screen" do
    delete session_url
    get stockbs_url
    assert_redirected_to new_session_url(format: :html)
  end

  test "index lists a row for each part with the stock summed up" do
    get stockbs_url
    assert_response :success
    assert_select "title", /Ｂ部品在庫表示/
    assert_select "tbody tr", count: 2
    cells = row_for("E001").css("td").map { |td| td.text.strip }
    # 部品コード 型式 和文 英文 販売単価 在庫数(10-3) 販売単位 重量 計測単位
    assert_equal [ "E001", "6L28HX", "和名1", "NAME 1", "12,000", "7", "10", "0.235", "2" ], cells
  end

  test "the headers are those of the old list of the B parts" do
    get stockbs_url
    assert_equal %w[部品コード 型式 和文名称 英文名称 販売単価 在庫数 販売単位 重量(kg) 計測単位], css_select("thead th").map { |th| th.text.strip }
  end

  test "a search with a tilde shows the parts with a tilde and the size column" do
    get stockbs_url(partno: "~")
    assert_select "tbody tr", count: 1
    assert_equal %w[部品コード 寸法 和文名称 英文名称 販売単価 在庫数 販売単位 重量(kg) 計測単位], css_select("thead th").map { |th| th.text.strip }
    assert_equal "50A", row_for("E500~").css("td")[1].text.strip
  end

  test "the part code can be searched by a part of it and the box keeps it" do
    get stockbs_url(partno: "e002")
    assert_select "tbody tr", count: 1
    assert row_for("E002")
    assert_select "input[name=partno][value=e002]"
  end

  test "the in stock check lists only the parts with stock" do
    Stockb.create!(partno: "E002", num: -4, novalid: 0)
    get stockbs_url(in_stock: "1")
    assert_select "tbody tr", count: 1
    assert row_for("E001")
    assert_select "input[type=checkbox][name=in_stock][checked]"
  end

  test "all stock lists the part whose stock is zero" do
    Stockb.create!(partno: "E002", num: -4, novalid: 0)
    get stockbs_url
    assert row_for("E002")
  end

  test "a row opens the stock maintenance of the part and the part code is a link to it" do
    get stockbs_url
    row = row_for("E001")
    assert_equal stockb_maintenance_path(partno: "E001"), row["data-row-link-url-value"]
    assert_select "tbody td a[href=?]", stockb_maintenance_path(partno: "E001"), text: "E001"
  end

  test "a hidden part is not listed" do
    StockbSetting.for_part("E001").update!(nonview: 1)
    get stockbs_url
    assert_select "tbody tr", count: 1
    assert_nil row_for("E001")
  end

  test "the button for a new stock goes to the form for a new B part stock" do
    get stockbs_url
    assert_select "a[href=?]", new_stockb_path, text: "新規在庫登録"
  end

  test "the list is paginated" do
    30.times do |i|
      pcode = format("F%03d", i)
      Kepart.create!(pcode: pcode, form: "x")
      Stockb.create!(partno: pcode, num: 1, novalid: 0)
    end
    get stockbs_url
    assert_select "tbody tr", count: 25
    assert_select "nav a[href*='page=2']"
    get stockbs_url(page: 2)
    assert_select "tbody tr", count: 7 # 「~」の無い部品 32件 - 25件
  end

  test "the explanation is in the annotation style" do
    get stockbs_url
    assert_select "p.TB12", text: /「~」/
  end
end
