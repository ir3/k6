require "test_helper"

# 新しい管理番号の採番（asp/orderin.asp を参考にした Order.next_mno）
class OrderTest < ActiveSupport::TestCase
  OCT = Date.new(2026, 10, 5)

  def make(mno, **attrs)
    Order.create!(mno: mno, adlist_id: 1, **attrs)
  end

  test "the first number of a month is the head of the month plus 1" do
    assert_equal 202_610_001, Order.next_mno(OCT)
  end

  test "continues from the largest number of the same month" do
    make(202_610_001)
    make(202_610_012)
    make(202_610_007)
    assert_equal 202_610_013, Order.next_mno(OCT)
  end

  test "starts again from 1 when the month changes" do
    make(202_609_078)
    assert_equal 202_610_001, Order.next_mno(OCT)
    assert_equal 202_609_079, Order.next_mno(Date.new(2026, 9, 30))
  end

  test "crossing the year numbers from the new year" do
    make(202_612_040)
    assert_equal 202_701_001, Order.next_mno(Date.new(2027, 1, 4))
  end

  test "an abnormal huge number does not break the numbering (the real 405024078 case)" do
    make(405_024_078)
    make(405_024_077)
    make(202_610_012)
    assert_equal 202_610_013, Order.next_mno(OCT)
  end

  test "a number of a later month does not push this month's numbers" do
    make(202_611_030)
    make(202_610_004)
    assert_equal 202_610_005, Order.next_mno(OCT)
  end

  test "old 8-digit numbers do not affect the numbering" do
    make(20_000_718)
    assert_equal 202_610_001, Order.next_mno(OCT)
  end

  test "the number of a deleted newest order is used again" do
    make(202_610_023)
    make(202_610_024, deleted_at: Time.current)
    assert_equal 202_610_024, Order.next_mno(OCT)
  end

  test "a deleted order in the middle leaves a gap and the next number is still max plus 1" do
    make(202_610_020, deleted_at: Time.current)
    make(202_610_021)
    assert_equal 202_610_022, Order.next_mno(OCT)
  end

  test "when every order of the month is deleted the month starts again from 1" do
    make(202_610_001, deleted_at: Time.current)
    assert_equal 202_610_001, Order.next_mno(OCT)
  end

  test "the last number of a month is 999 and there is no next one" do
    make(202_610_998)
    assert_equal 202_610_999, Order.next_mno(OCT)
    make(202_610_999)
    assert_nil Order.next_mno(OCT)
  end

  test "defaults to the current month" do
    travel_to Time.zone.local(2026, 10, 5, 12) do
      make(202_610_020)
      assert_equal 202_610_021, Order.next_mno
    end
  end
  # 点数（旧 partsin.asp の Pnum）
  def order_with_lines
    order = Order.create!(mno: 202611100)
    Part.create!(pcode: "PN-A1", newprice: 1)
    Part.create!(pcode: "PN-A2", newprice: 1)
    Kepart.create!(pcode: "PN-B1~", newprice: 1)
    Orderpart.create!(mno: order.mno, sno: 10, partno: "PN-A1", qty: 1, unitpd: 1)
    Orderpart.create!(mno: order.mno, sno: 20, partno: "PN-A1", kzaiko: "^", qty: 1, unitpd: 1)
    Orderpart.create!(mno: order.mno, sno: 30, partno: "PN-A2", qty: 1, unitpd: 1)
    Orderpart.create!(mno: order.mno, sno: 40, partno: "PN-B1~", qty: 1, unitpd: 1)
    Orderpart.create!(mno: order.mno, sno: 50, partno: "NO-MASTER", qty: 1, unitpd: 1)
    NOrderpart.create!(mno: order.mno, sno: 60, partsname: "部品番号なし", qty: 1, tvalid: 1)
    NOrderpart.create!(mno: order.mno, sno: 70, partsname: "取り消した", qty: 1, tvalid: 0)
    order
  end

  test "the number of items is the number of the rows of the order detail without the cancelled rows" do
    order = order_with_lines
    # A部品3（在庫「^」の行を含む）・B部品1・部品番号不明1・部品番号なしの有効な1。取り消した1行は数えない
    assert_equal 6, order.parts_count
  end

  test "a deleted row is not counted and an order without rows is 0" do
    order = order_with_lines
    Orderpart.where(mno: order.mno, partno: "PN-A2").first.update!(deleted_at: Time.current)
    assert_equal 5, order.parts_count
    assert_equal 0, Order.create!(mno: 202611101).parts_count
    assert_equal 0, Order.create!(mno: nil).parts_count
  end

  test "the rows of another order are not counted" do
    order = order_with_lines
    other = Order.create!(mno: 202611102)
    Orderpart.create!(mno: other.mno, sno: 10, partno: "PN-A1", qty: 1, unitpd: 1)
    assert_equal 6, order.parts_count
    assert_equal 1, other.parts_count
  end

  test "refreshing writes the number of items and returns it, and keeps the updated time" do
    order = order_with_lines
    order.update_columns(pnum: nil, updated_at: Time.zone.local(2026, 1, 2, 3, 4, 5))
    assert_equal 6, order.refresh_parts_count!
    order.reload
    assert_equal 6, order.pnum
    assert_equal Time.zone.local(2026, 1, 2, 3, 4, 5), order.updated_at
  end

  test "refreshing does not write when the number is already right" do
    order = order_with_lines
    order.refresh_parts_count!
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].match?(/\A\s*UPDATE/i) }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { order.refresh_parts_count! }
    assert_empty queries
  end
end
