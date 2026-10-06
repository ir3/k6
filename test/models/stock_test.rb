require "test_helper"

# 在庫台帳（Stock）の集計と区分名
class StockTest < ActiveSupport::TestCase
  def ledger(partno, num, **attrs)
    Stock.create!(partno: partno, num: num, **attrs)
  end

  test "on_hand is the sum of the in and out quantities of the part" do
    ledger("A001", 10)
    ledger("A001", -3)
    ledger("A001", 5)
    ledger("B002", 100)
    assert_equal 12, Stock.on_hand("A001")
  end

  test "on_hand is 0 for a part without rows" do
    assert_equal 0, Stock.on_hand("NOPE")
  end

  test "on_hand ignores deleted rows and invalid rows" do
    ledger("A001", 10)
    ledger("A001", 7, deleted_at: Time.current)
    ledger("A001", 5, novalid: 1)
    ledger("A001", 2, novalid: 0)
    assert_equal 12, Stock.on_hand("A001")
  end

  test "the part number is matched ignoring case and surrounding spaces" do
    ledger("a001", 4)
    ledger("A001", 6)
    assert_equal 10, Stock.on_hand(" a001 ")
    assert_equal 2, Stock.of_part("A001").count
  end

  test "kind_labels gives the names of the in and out kinds" do
    assert_equal [ "買取品" ], Stock.new(ikubun: 1, okubun: 0).kind_labels
    assert_equal [ "返品(貸出分)" ], Stock.new(ikubun: 2).kind_labels
    assert_equal [ "返品(キャンセル)" ], Stock.new(ikubun: 3).kind_labels
    assert_equal [ "返品(誤送品)" ], Stock.new(ikubun: 4).kind_labels
    assert_equal [ "貸出分" ], Stock.new(ikubun: 0, okubun: 1).kind_labels
    assert_equal [ "売掛分" ], Stock.new(ikubun: 0, okubun: 2).kind_labels
    assert_equal [], Stock.new(ikubun: 0, okubun: 0).kind_labels
    assert_equal [], Stock.new.kind_labels
  end
end
