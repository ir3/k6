require "test_helper"

# 注文部品詳細画面の「各種出力日」（旧 partsin.asp の請求管理）。帳票出力履歴（order_logs）から求める
class OrderOutputDatesTest < ActiveSupport::TestCase
  MNO = 202611001

  def log(kubun, date, stamp = nil)
    stamp ||= Time.zone.local(date.year, date.month, date.day, 9, 0, 0)
    OrderLog.create!(tvalid: 1, mno: MNO, kubun: kubun, datelog: date, created_at: stamp, updated_at: stamp)
  end

  def dates(mno = MNO)
    OrderOutputDates.new(mno).call
  end

  test "an order without any output has no dates" do
    assert_equal [ nil ] * 8, dates.to_h.values
  end

  test "each automatic kind goes to its own item" do
    log(1, Date.new(2026, 11, 1))
    log(3, Date.new(2026, 11, 3))
    log(4, Date.new(2026, 11, 4))
    log(5, Date.new(2026, 11, 5))
    log(6, Date.new(2026, 11, 6))
    log(7, Date.new(2026, 11, 7))
    result = dates
    assert_equal Date.new(2026, 11, 1), result.request.date
    assert_equal Date.new(2026, 11, 3), result.order_memo.date
    assert_equal Date.new(2026, 11, 4), result.shipping.date
    assert_equal Date.new(2026, 11, 5), result.invoice.date
    assert_equal Date.new(2026, 11, 6), result.payment.date
    assert_equal Date.new(2026, 11, 7), result.delivery.date
    assert_nil result.first_estimate
    assert_nil result.latest_estimate
    assert_equal [ false ] * 6, [ result.request, result.order_memo, result.shipping, result.invoice, result.payment, result.delivery ].map(&:manual)
  end

  test "the estimate has the first and the latest date of the automatic records" do
    log(2, Date.new(2026, 11, 1))
    log(2, Date.new(2026, 11, 8))
    log(2, Date.new(2026, 11, 5))
    result = dates
    # 更新日時の順に読むので、最後に記録されたものが最新
    assert_equal Date.new(2026, 11, 1), result.first_estimate.date
    assert_equal Date.new(2026, 11, 8), result.latest_estimate.date
  end

  test "a single automatic estimate is both the first and the latest" do
    log(2, Date.new(2026, 11, 2))
    assert_equal [ Date.new(2026, 11, 2) ] * 2, [ dates.first_estimate.date, dates.latest_estimate.date ]
  end

  test "a manual date replaces the automatic date of the same item and is marked as manual" do
    log(4, Date.new(2026, 11, 4))
    log(104, Date.new(2026, 11, 20))
    log(7, Date.new(2026, 11, 7))
    result = dates
    assert_equal [ Date.new(2026, 11, 20), true ], [ result.shipping.date, result.shipping.manual ]
    assert_equal [ Date.new(2026, 11, 7), false ], [ result.delivery.date, result.delivery.manual ]
  end

  test "a manual date alone is shown" do
    log(106, Date.new(2026, 11, 30))
    assert_equal [ Date.new(2026, 11, 30), true ], [ dates.payment.date, dates.payment.manual ]
  end

  test "a manual estimate is the latest estimate when there is no automatic one, and there is no first estimate" do
    log(102, Date.new(2026, 11, 6))
    result = dates
    assert_equal [ Date.new(2026, 11, 6), true ], [ result.latest_estimate.date, result.latest_estimate.manual ]
    assert_nil result.first_estimate
  end

  test "a manual estimate replaces the latest estimate when there is one automatic estimate" do
    log(2, Date.new(2026, 11, 1), Time.zone.local(2026, 11, 1, 9))
    log(102, Date.new(2026, 11, 9), Time.zone.local(2026, 11, 2, 9))
    result = dates
    assert_equal Date.new(2026, 11, 1), result.first_estimate.date
    assert_equal [ Date.new(2026, 11, 9), true ], [ result.latest_estimate.date, result.latest_estimate.manual ]
  end

  test "with several automatic estimates a manual one wins only if it was recorded after the latest automatic one" do
    log(2, Date.new(2026, 11, 1), Time.zone.local(2026, 11, 1, 9))
    log(2, Date.new(2026, 11, 8), Time.zone.local(2026, 11, 8, 9))
    log(102, Date.new(2026, 11, 9), Time.zone.local(2026, 11, 5, 9)) # 自動の最新より古い記録
    result = dates
    assert_equal [ Date.new(2026, 11, 8), false ], [ result.latest_estimate.date, result.latest_estimate.manual ]

    log(102, Date.new(2026, 11, 10), Time.zone.local(2026, 11, 12, 9)) # 新しい記録
    result = dates
    assert_equal [ Date.new(2026, 11, 10), true ], [ result.latest_estimate.date, result.latest_estimate.manual ]
    assert_equal Date.new(2026, 11, 1), result.first_estimate.date
  end

  test "other orders and unknown kinds are ignored" do
    OrderLog.create!(tvalid: 1, mno: MNO + 1, kubun: 5, datelog: Date.new(2026, 11, 5))
    log(9, Date.new(2026, 11, 9))
    assert_equal [ nil ] * 8, dates.to_h.values
  end
end
