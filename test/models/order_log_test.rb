# frozen_string_literal: true

require "test_helper"

class OrderLogTest < ActiveSupport::TestCase
  test "latest_date はその注文・区分の最後の出力日を返し、無ければnil" do
    OrderLog.record(mno: 202610001, kubun: OrderLog::KUBUN_SYUKKA_ANNAI, date: Date.new(2026, 10, 1))
    OrderLog.record(mno: 202610001, kubun: OrderLog::KUBUN_SYUKKA_ANNAI, date: Date.new(2026, 10, 5))
    OrderLog.record(mno: 202610001, kubun: OrderLog::KUBUN_SEIKYU, date: Date.new(2026, 10, 9))
    OrderLog.record(mno: 202610002, kubun: OrderLog::KUBUN_SYUKKA_ANNAI, date: Date.new(2026, 10, 7))

    assert_equal Date.new(2026, 10, 5), OrderLog.latest_date(202610001, OrderLog::KUBUN_SYUKKA_ANNAI)
    assert_nil OrderLog.latest_date(202610003, OrderLog::KUBUN_SYUKKA_ANNAI)
  end

  test "請求書の出荷日は、出荷案内書の履歴があればそれ、無ければ指定出荷日、受注日の順" do
    order = Order.create!(mno: 202610010, adlist_id: 1, shipname: "第一丸", rdate: Date.new(2026, 10, 2), syuday: Date.new(2026, 10, 3))
    label = ->(o) { XlsxReports::SeikyuReport.new(o).send(:shipping_date_label) }

    assert_equal "2026年10月3日", label.call(order)
    OrderLog.record(mno: order.mno, kubun: OrderLog::KUBUN_SYUKKA_ANNAI, date: Date.new(2026, 10, 8))
    assert_equal "2026年10月8日", label.call(order)
    assert_equal "2026年10月2日", label.call(Order.create!(mno: 202610011, adlist_id: 1, shipname: "第二丸", rdate: Date.new(2026, 10, 2)))
  end
end
