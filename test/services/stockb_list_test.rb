require "test_helper"

# Ｂ部品在庫の一覧（旧 hzaikolist.asp → hzaikosel.asp）の集計
class StockbListTest < ActiveSupport::TestCase
  setup do
    @k1 = Kepart.create!(pcode: "E001", form: "6L28HX", size: "10x20", jname: "和名1", ename: "NAME 1", newprice: 1200,
                         sel_unit: "10", weightkg: 0.5, munit: 2)
    @k2 = Kepart.create!(pcode: "E002", form: "6M31", jname: "和名2", ename: "NAME 2", newprice: 300)
    @kt = Kepart.create!(pcode: "E500~", form: "寸法違い", size: "50A", jname: "和名T", ename: "NAME T", newprice: 80)
    Stockb.create!(partno: "E001", num: 10, novalid: 0)
    Stockb.create!(partno: "E001", num: -3, novalid: 0)
    Stockb.create!(partno: "E002", num: 4)
    Stockb.create!(partno: "E500~", num: 6, novalid: 0)
  end

  def codes(**options)
    StockbList.new(**options).rows.map(&:pcode)
  end

  test "each kepart with ledger lines is one row with the stock summed up" do
    row = StockbList.new.rows.find { |r| r.pcode == "E001" }
    assert_equal [ "E001", "6L28HX", "和名1", "NAME 1", 1200, "10", 0.5, 2, 7 ],
                 [ row.pcode, row.second, row.jname, row.ename, row.price, row.sel_unit, row.weightkg, row.munit, row.on_hand ]
  end

  test "parts are in the order of the part code without regard to case" do
    Kepart.create!(pcode: "e000", form: "x")
    Stockb.create!(partno: "E000", num: 1)
    assert_equal %w[e000 E001 E002], codes
  end

  test "a kepart without any ledger line is not listed (inner join)" do
    Kepart.create!(pcode: "E003", form: "x")
    assert_not_includes codes, "E003"
  end

  test "a part that is only in the ledger is not listed" do
    Stockb.create!(partno: "LEDGERONLY", num: 5)
    assert_not_includes codes, "LEDGERONLY"
  end

  test "the ledger and the kepart are matched without regard to case and spaces" do
    Kepart.create!(pcode: "E009", form: "x")
    Stockb.create!(partno: "e009", num: 2)
    assert_equal 2, StockbList.new.rows.find { |r| r.pcode == "E009" }.on_hand
  end

  test "deleted and invalid lines are not counted" do
    Stockb.create!(partno: "E001", num: 100, deleted_at: Time.current)
    Stockb.create!(partno: "E001", num: 100, novalid: 1)
    assert_equal 7, StockbList.new.rows.find { |r| r.pcode == "E001" }.on_hand
  end

  test "a part whose lines are all invalid is not listed" do
    Kepart.create!(pcode: "E004", form: "x")
    Stockb.create!(partno: "E004", num: 9, novalid: 1)
    assert_not_includes codes, "E004"
  end

  test "the part code can be searched by a part of it, without regard to case" do
    assert_equal %w[E001], codes(partno: "001")
    assert_equal %w[E001 E002], codes(partno: "e00")
    assert_empty codes(partno: "ZZZ")
  end

  test "the characters of the search are not taken as wildcards" do
    assert_empty codes(partno: "%")
    assert_empty codes(partno: "E00_")
  end

  test "without a tilde in the search, the parts with a tilde are not listed and the second column is the form" do
    list = StockbList.new
    assert_equal "型式", list.second_title
    assert_equal %w[E001 E002], list.rows.map(&:pcode)
    assert_equal "6L28HX", list.rows.first.second
  end

  test "with a tilde in the search, only the parts with a tilde are listed and the second column is the size" do
    list = StockbList.new(partno: "~")
    assert_equal "寸法", list.second_title
    assert_equal %w[E500~], list.rows.map(&:pcode)
    assert_equal "50A", list.rows.first.second
  end

  test "a search with a tilde that matches only a part of the code works" do
    assert_equal %w[E500~], codes(partno: "0~")
  end

  test "in_stock lists only the parts with stock above zero" do
    Stockb.create!(partno: "E002", num: -4)
    assert_equal %w[E001], codes(in_stock: true)
    assert_equal %w[E500~], codes(partno: "~", in_stock: true)
    assert_equal %w[E001 E002], codes(in_stock: false)
  end

  test "a negative stock is listed in all stock but not in stock" do
    Stockb.create!(partno: "E002", num: -9)
    assert_equal(-5, StockbList.new.rows.find { |r| r.pcode == "E002" }.on_hand)
    assert_not_includes codes(in_stock: true), "E002"
  end

  test "a part set to hidden is not listed, in all stock nor in stock" do
    StockbSetting.for_part("e001").update!(nonview: 1)
    assert_equal %w[E002], codes
    assert_equal %w[E002], codes(in_stock: true)
  end

  test "a part set back to shown is listed again" do
    StockbSetting.for_part("E001").update!(nonview: 1)
    StockbSetting.for_part("E001").update!(nonview: nil)
    assert_equal %w[E001 E002], codes
  end

  test "a hidden part with a tilde is not listed in the tilde search" do
    StockbSetting.for_part("E500~").update!(nonview: 1)
    assert_empty codes(partno: "~")
  end
end
