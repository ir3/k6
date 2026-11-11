require "test_helper"

# Ａ部品在庫表示（旧 zaikolist.asp → zaikosel.asp）のテスト。部品ごとに在庫の増減を集計して並べる
class StocksControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    Part.create!(pcode: "A001", form: "6L28HX", jname: "和名A", ename: "NAME A", newprice: 12_000,
                 sel_unit: "10", weightkg: 0.235, munit: 2)
    Part.create!(pcode: "B002", form: "6M31AFT", jname: "和名B", ename: "NAME B", newprice: 500)
    Stock.create!(partno: "A001", num: 10, onum: 0, novalid: 0)
    Stock.create!(partno: "A001", num: -3, onum: 5, novalid: 0)
    Stock.create!(partno: "B002", num: 4, onum: 0, novalid: 0)
    StockSetting.create!(partno: "A001", snum: 4, znum: 2)
  end

  # 部品コードの行（<tr>）をとる
  def row_for(pcode)
    css_select("tbody tr").find { |tr| tr.at_css("td")&.text&.strip == pcode }
  end

  test "someone who is not signed in is sent to the login screen" do
    delete session_url
    get stocks_url
    assert_redirected_to new_session_url(format: :html)
  end

  test "index lists a row for each part with the stock summed up" do
    get stocks_url
    assert_response :success
    assert_select "tbody tr", count: 2
    cells = row_for("A001").css("td").map { |td| td.text.strip }
    # 部品コード 形式 和文 英文 販売単価 在庫数(10-3) 標準在庫 予測量 必要在庫(4+2) 発注中 販売単位 重量 計測単位
    assert_equal [ "A001", "6L28HX", "和名A", "NAME A", "12,000", "7", "4", "2", "6", "5", "10", "0.235", "2" ], cells
  end

  test "the headers are those of the old stock list" do
    get stocks_url
    headers = css_select("thead th").map { |th| th.text.strip }
    assert_equal %w[部品コード 形式 和文名称 英文名称 販売単価 在庫数 標準在庫 予測量 必要在庫 発注中 販売単位 重量(kg) 計測単位], headers
  end

  test "the stock number is red when it is less than the required stock, and the row is tinted" do
    StockSetting.find_by!(partno: "A001").update!(snum: 10, znum: 5) # 必要在庫15 > 在庫7
    get stocks_url
    row = row_for("A001")
    assert_match(/background-color: cornsilk/, row["style"])
    assert_match(/var\(--color-error\)/, row.css("td")[5]["style"])
    assert_nil row_for("B002")["style"]
    assert_nil row_for("B002").css("td")[5]["style"]
  end

  test "a row opens the stock maintenance of the part when it is clicked" do
    get stocks_url
    row = row_for("A001")
    assert_equal "row-link", row["data-controller"]
    assert_equal stock_maintenance_path(partno: "A001"), row["data-row-link-url-value"]
    assert_select "td a[href=?]", stock_maintenance_path(partno: "A001"), text: "A001"
  end

  test "the part code can be searched by a part of it" do
    get stocks_url(partno: "b00")
    assert_select "tbody tr", count: 1
    assert_not_nil row_for("B002")
    assert_select "input[name=partno][value=?]", "b00"
  end

  test "in_stock leaves out the parts with no stock" do
    Stock.create!(partno: "B002", num: -4, onum: 0, novalid: 0)
    get stocks_url(in_stock: 1)
    assert_select "tbody tr", count: 1
    assert_not_nil row_for("A001")
    assert_select "input[type=checkbox][name=in_stock][checked]"
  end

  test "parts set to hidden are not listed, unless only the parts in stock are asked for" do
    StockSetting.find_by!(partno: "A001").update!(nonview: 1)
    get stocks_url
    assert_nil row_for("A001")
    assert_not_nil row_for("B002")

    get stocks_url(in_stock: 1)
    assert_not_nil row_for("A001")
  end

  test "the new stock registration is linked" do
    get stocks_url
    assert_select "a[href=?]", new_stock_path, text: "新規在庫登録"
  end

  test "the explanation is in the annotation style, and not on the table headers" do
    get stocks_url
    assert_select "p.TB12", text: /在庫メンテナンスを開きます/
    assert_select "th.TB12, th .TB12", false
  end

  test "the list is paginated" do
    30.times do |i|
      pcode = format("P%03d", i)
      Part.create!(pcode: pcode)
      Stock.create!(partno: pcode, num: 1, novalid: 0)
    end
    get stocks_url
    assert_select "tbody tr", count: 25
    assert_select "nav a[href*='page=2']"
    get stocks_url(page: 2)
    assert_select "tbody tr", count: 7 # 32件 - 25件
  end
end
