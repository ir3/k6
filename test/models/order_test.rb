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

  test "a deleted order still uses up its number" do
    make(202_610_009, deleted_at: Time.current)
    assert_equal 202_610_010, Order.next_mno(OCT)
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
end
