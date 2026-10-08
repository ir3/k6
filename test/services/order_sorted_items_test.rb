# frozen_string_literal: true

require "test_helper"

class OrderSortedItemsTest < ActiveSupport::TestCase
  setup do
    @order = Order.create!(mno: 202610001, adlist_id: 1, shipname: "第一丸", irate: 1.0)
    Orderpart.create!(mno: @order.mno, sno: 10, partno: "A001", qty: 2, unitpd: 1000, irate: 1.0, totala: 2000)
    Orderpart.create!(mno: @order.mno, sno: 20, partno: "A002", qty: 0, unitpd: 500, irate: 1.0, totala: 0)
    Orderpart.create!(mno: @order.mno, sno: 30, partno: "A003", qty: 3, unitpd: 300, irate: 1.0, totala: 900)
    NOrderpart.create!(mno: @order.mno, sno: 40, partsname: "数量0の作業費", qty: 0, unitpd: 5000, rate: 1.0, totala: 0, tvalid: 1)
  end

  test "forは数量0の明細も含み、printableは数量0を除いて順を保ったまま上に詰める" do
    assert_equal [ 10, 20, 30, 40 ], OrderSortedItems.for(@order).map(&:sno)
    assert_equal [ 10, 30 ], OrderSortedItems.printable(@order).map(&:sno)
  end

  test "printableはバラ売りの明細を、バラ数量があれば残す" do
    Orderpart.create!(mno: @order.mno, sno: 50, partno: "A004", qty: 0, bqty: 5, unit: "10", unitpd: 1000, irate: 1.0, totala: 500)
    assert_includes OrderSortedItems.printable(@order).map(&:sno), 50
  end
end
