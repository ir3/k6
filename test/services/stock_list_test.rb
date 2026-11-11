require "test_helper"

# Ａ部品在庫表示（旧 zaikolist.asp → zaikosel.asp）の一覧のテスト
class StockListTest < ActiveSupport::TestCase
  setup do
    Part.create!(pcode: "A001", form: "6L28HX", jname: "和名A", ename: "NAME A", newprice: 12_000,
                 sel_unit: "10", weightkg: 0.235, munit: 2)
    Part.create!(pcode: "B002", form: "6M31AFT", jname: "和名B", ename: "NAME B", newprice: 500, sel_unit: "1",
                 weightkg: 1.5, munit: 1)
  end

  def stock(partno, num, **attrs)
    Stock.create!({ partno: partno, num: num, onum: 0, novalid: 0 }.merge(attrs))
  end

  def list(**options)
    StockList.new(**options).rows
  end

  def row_of(rows, pcode)
    rows.find { |row| row.pcode == pcode }
  end

  test "sums the increases and decreases of the ledger for each part" do
    stock("A001", 10)
    stock("A001", -3)
    stock("A001", 5)
    stock("B002", 4)
    rows = list
    assert_equal 12, row_of(rows, "A001").on_hand
    assert_equal 4, row_of(rows, "B002").on_hand
  end

  test "the columns of the part ledger are shown with the stock number" do
    stock("A001", 1)
    row = row_of(list, "A001")
    assert_equal "6L28HX", row.form
    assert_equal "和名A", row.jname
    assert_equal "NAME A", row.ename
    assert_equal 12_000, row.price
    assert_equal "10", row.sel_unit
    assert_in_delta 0.235, row.weightkg
    assert_equal 2, row.munit
  end

  test "the part code is matched without regard to case, and the part ledger spelling is shown" do
    stock("a001", 6)
    stock("A001", 4)
    rows = list
    assert_equal 1, rows.count { |row| row.pcode == "A001" }
    assert_equal 10, row_of(rows, "A001").on_hand
  end

  test "deleted and invalid ledger lines are not counted, as in the stock maintenance screen" do
    stock("A001", 10)
    stock("A001", 100, deleted_at: Time.current)
    stock("A001", 1000, novalid: 1)
    assert_equal 10, row_of(list, "A001").on_hand
    assert_equal Stock.on_hand("A001"), row_of(list, "A001").on_hand
  end

  test "a part that is only in the stock ledger and not in the part ledger is not listed, as before" do
    stock("A001", 1)
    stock("ONLYLEDGER", 9)
    assert_equal [ "A001" ], list.map(&:pcode)
  end

  test "a part without any line in the stock ledger is not listed" do
    stock("A001", 1)
    assert_nil row_of(list, "B002")
  end

  test "a deleted part is not listed" do
    stock("A001", 1)
    Part.find_by!(pcode: "A001").update!(deleted_at: Time.current)
    assert_empty list
  end

  test "the number on order is the sum of Onum of the ledger" do
    stock("A001", 5, onum: 3)
    stock("A001", 2, onum: 4)
    stock("B002", 1)
    assert_equal 7, row_of(list, "A001").ordered
    assert_equal 0, row_of(list, "B002").ordered
  end

  test "the standard stock and the forecast come from the stock settings, and the required stock is their sum" do
    stock("A001", 5)
    StockSetting.create!(partno: "A001", snum: 4, znum: 6)
    row = row_of(list, "A001")
    assert_equal 4, row.standard
    assert_equal 6, row.forecast
    assert_equal 10, row.required
  end

  test "a part without settings has 0 for the standard stock, the forecast and the required stock" do
    stock("B002", 5)
    row = row_of(list, "B002")
    assert_equal [ 0, 0, 0 ], [ row.standard, row.forecast, row.required ]
  end

  test "a setting with only one of the two numbers counts the other as 0" do
    stock("A001", 5)
    StockSetting.create!(partno: "A001", snum: 3, znum: nil)
    assert_equal 3, row_of(list, "A001").required
  end

  test "the settings are found even when the setting is kept in lower case or with spaces" do
    stock("A001", 5)
    StockSetting.create!(partno: " a001 ", snum: 7, znum: 1)
    assert_equal 8, row_of(list, "A001").required
  end

  test "a part is short when the stock number is less than the required stock" do
    stock("A001", 5)
    StockSetting.create!(partno: "A001", snum: 4, znum: 2)
    assert row_of(list, "A001").short?
  end

  test "a part is not short when the stock number equals the required stock or more" do
    stock("A001", 6)
    stock("B002", 9)
    StockSetting.create!(partno: "A001", snum: 4, znum: 2)
    StockSetting.create!(partno: "B002", snum: 4, znum: 2)
    assert_not row_of(list, "A001").short?
    assert_not row_of(list, "B002").short?
  end

  test "a part with no required stock set is short only when the stock number is below 0" do
    stock("A001", -1)
    stock("B002", 0)
    assert row_of(list, "A001").short?
    assert_not row_of(list, "B002").short?
  end

  test "the stock number that is NULL is never short" do
    stock("A001", nil)
    StockSetting.create!(partno: "A001", snum: 4, znum: 2)
    row = row_of(list, "A001")
    assert_nil row.on_hand
    assert_not row.short?
  end

  test "parts set to hidden are left out" do
    stock("A001", 5)
    stock("B002", 5)
    StockSetting.create!(partno: "A001", nonview: 1)
    assert_equal [ "B002" ], list.map(&:pcode)
  end

  test "a setting that is not hidden does not hide the part" do
    stock("A001", 5)
    StockSetting.create!(partno: "A001", nonview: 0, snum: 1)
    StockSetting.create!(partno: "B002", nonview: nil)
    stock("B002", 5)
    assert_equal %w[A001 B002], list.map(&:pcode)
  end

  test "parts with no stock are listed unless only parts in stock are asked for" do
    stock("A001", 5)
    stock("B002", 0)
    assert_equal %w[A001 B002], list.map(&:pcode)
    assert_equal [ "A001" ], list(in_stock: true).map(&:pcode)
  end

  test "only parts in stock does not look at the hidden setting, as before" do
    stock("A001", 5)
    StockSetting.create!(partno: "A001", nonview: 1)
    assert_empty list
    assert_equal [ "A001" ], list(in_stock: true).map(&:pcode)
  end

  test "only parts in stock leaves out the parts whose stock number is NULL or minus" do
    stock("A001", nil)
    stock("B002", -2)
    assert_empty list(in_stock: true)
  end

  test "a part of the part code is searched without regard to case" do
    stock("A001", 1)
    stock("B002", 1)
    assert_equal [ "B002" ], list(partno: "b00").map(&:pcode)
    assert_equal [ "A001" ], list(partno: "01").map(&:pcode)
    assert_equal %w[A001 B002], list(partno: "").map(&:pcode)
    assert_equal %w[A001 B002], list(partno: nil).map(&:pcode)
  end

  test "spaces around the searched part code are ignored" do
    stock("A001", 1)
    assert_equal [ "A001" ], list(partno: "  A00 ").map(&:pcode)
  end

  test "% and _ in the searched part code are not wildcards" do
    Part.create!(pcode: "X_1", jname: "アンダースコア")
    Part.create!(pcode: "XA1", jname: "ふつう")
    stock("X_1", 1)
    stock("XA1", 1)
    assert_equal [ "X_1" ], list(partno: "X_1").map(&:pcode)
    assert_empty list(partno: "%")
  end

  test "the rows are in order of the part code" do
    Part.create!(pcode: "a000", jname: "小文字の部品")
    %w[B002 A001 a000].each { |pcode| stock(pcode, 1) }
    assert_equal %w[a000 A001 B002], list.map(&:pcode)
  end

  test "the same numbers as the stock maintenance screen for every part" do
    stock("A001", 7)
    stock("A001", -2)
    stock("a001", 1, novalid: 1)
    stock("B002", 3, deleted_at: Time.current)
    stock("B002", 8)
    list.each { |row| assert_equal Stock.on_hand(row.pcode), row.on_hand, row.pcode }
  end
end
