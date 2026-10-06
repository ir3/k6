require "test_helper"

# 在庫メンテナンスの「この部品の入出荷状況」
class StockHistoryTest < ActiveSupport::TestCase
  def ledger(num, minutes_ago, **attrs)
    Stock.create!(partno: "A001", num: num, irprice: 1000, updated_at: minutes_ago.minutes.ago, **attrs)
  end

  test "rows are newest first by the update time" do
    old = ledger(1, 30, memo: "古い")
    new = ledger(1, 10, memo: "新しい")
    mid = ledger(1, 20, memo: "中間")
    assert_equal [ new.memo, mid.memo, old.memo ], StockHistory.new("A001").rows.map(&:note)
  end

  test "an in row and an out row show the quantity and the amount on their own side" do
    ledger(5, 20)
    ledger(-2, 10)
    out, inn = StockHistory.new("A001").rows
    assert_equal [ nil, nil, 2, 2000 ], [ out.in_qty, out.in_amount, out.out_qty, out.out_amount ]
    assert_equal [ 5, 5000, nil, nil ], [ inn.in_qty, inn.in_amount, inn.out_qty, inn.out_amount ]
  end

  test "a row with quantity 0 (an order only) shows neither in nor out" do
    ledger(0, 10, onum: 4)
    row = StockHistory.new("A001").rows.sole
    assert_equal [ nil, nil, nil, nil, 4 ], [ row.in_qty, row.in_amount, row.out_qty, row.out_amount, row.ordered ]
  end

  test "the note puts the kind names before the memo" do
    ledger(5, 30, ikubun: 1, memo: "メモ")
    ledger(-1, 20, ikubun: 0, okubun: 2, memo: "調整")
    ledger(-1, 10, ikubun: 0, okubun: 0)
    assert_equal [ "", "売掛分　調整", "買取品　メモ" ], StockHistory.new("A001").rows.map(&:note)
  end

  test "the note is only the kind name when there is no memo, with no trailing space" do
    ledger(-1, 20, okubun: 2)
    ledger(5, 10, ikubun: 3, memo: "")
    assert_equal [ "返品(キャンセル)", "売掛分" ], StockHistory.new("A001").rows.map(&:note)
  end

  test "the date is the in date, then the out date, then the update date" do
    travel_to Time.zone.local(2026, 10, 6, 12) do
      ledger(1, 30, indate: Date.new(2026, 1, 2), outdate: Date.new(2026, 2, 3))
      ledger(1, 20, outdate: Date.new(2026, 2, 3))
      ledger(1, 10)
      dates = StockHistory.new("A001").rows.map(&:date)
      assert_equal [ Date.new(2026, 10, 6), Date.new(2026, 2, 3), Date.new(2026, 1, 2) ], dates
    end
  end

  test "the company and the ship come from the order when there is a trade number" do
    adlist = Adlist.create!(no: "9001", company: "テスト海運株式会社", ruby: "てすと")
    Order.create!(mno: 202610001, adlist_id: 9001, shipname: "注文の船")
    ledger(-1, 10, mno: 202610001, cname: "メモの会社", sname: "メモの船")
    row = StockHistory.new("A001").rows.sole
    assert_equal [ adlist.company, "注文の船", 202610001 ], [ row.company, row.shipname, row.mno ]
    assert_equal 202610001, row.order.mno
  end

  test "the memo company and ship are used when there is no trade number or the order is deleted" do
    Order.create!(mno: 202610002, adlist_id: 1, shipname: "削除済みの船", deleted_at: Time.current)
    ledger(-1, 20, mno: 0, cname: "メモの会社", sname: "メモの船")
    ledger(-1, 10, mno: 202610002, cname: "別のメモの会社", sname: "別のメモの船")
    deleted, no_mno = StockHistory.new("A001").rows
    assert_equal [ "別のメモの会社", "別のメモの船", nil ], [ deleted.company, deleted.shipname, deleted.order ]
    assert_equal [ "メモの会社", "メモの船", nil, nil ], [ no_mno.company, no_mno.shipname, no_mno.mno, no_mno.order ]
  end

  test "only the first 21 rows are listed until all are asked for" do
    25.times { |i| ledger(1, 100 - i, memo: "行#{i}") }
    history = StockHistory.new("A001")
    assert_equal 21, history.rows.size
    assert_equal 25, history.total
    assert history.truncated?

    all = StockHistory.new("A001", all: true)
    assert_equal 25, all.rows.size
    assert_not all.truncated?
  end

  test "exactly 21 rows are not truncated" do
    21.times { |i| ledger(1, 100 - i) }
    assert_not StockHistory.new("A001").truncated?
  end

  test "deleted rows and other parts are not listed, and the part number ignores case" do
    ledger(1, 10, memo: "有効")
    ledger(1, 20, memo: "削除済み", deleted_at: Time.current)
    Stock.create!(partno: "B002", num: 1)
    Stock.create!(partno: "a001", num: 1, memo: "小文字の部品番号")
    assert_equal [ "小文字の部品番号", "有効" ].sort, StockHistory.new(" a001").rows.map(&:note).sort
  end
end
