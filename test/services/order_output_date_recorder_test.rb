require "test_helper"

# 注文部品詳細画面の「日付更新」（旧 torihikikanri.asp）。チェックした項目ごとに、手動の記録を1行ずつ足す
class OrderOutputDateRecorderTest < ActiveSupport::TestCase
  setup do
    @order = Order.create!(mno: 202611001, shipname: "第一丸")
  end

  def record(kubuns, date)
    OrderOutputDateRecorder.new(@order, kubuns, date).call
  end

  def logs
    OrderLog.where(mno: @order.mno).order(:id).pluck(:kubun, :datelog)
  end

  test "adds one manual record for each checked item with the entered date" do
    result = record(%w[104 105 106], "2026-11-12")
    assert result.success?
    assert_equal Date.new(2026, 11, 12), result.date
    assert_equal %w[出荷案内出力日 請求書出力日 入金(確認)日], result.labels
    assert_equal [ [ 104, Date.new(2026, 11, 12) ], [ 105, Date.new(2026, 11, 12) ], [ 106, Date.new(2026, 11, 12) ] ], logs
    assert_equal [ 1 ], OrderLog.where(mno: @order.mno).pluck(:tvalid).uniq
  end

  test "all six items of the old screen are accepted" do
    assert record(%w[102 103 104 105 106 107], "2026-11-12").success?
    assert_equal [ 102, 103, 104, 105, 106, 107 ], logs.map(&:first).sort
  end

  test "the dates are shown by OrderOutputDates as manual dates" do
    record(%w[107], "2026/11/20")
    entry = OrderOutputDates.new(@order.mno).call.delivery
    assert_equal [ Date.new(2026, 11, 20), true ], [ entry.date, entry.manual ]
  end

  test "the date can be written like the old screen, with slashes, one-digit month and day, or full-width digits" do
    { "2026/11/05" => Date.new(2026, 11, 5), "2026/1/2" => Date.new(2026, 1, 2), "２０２６／１１／０５" => Date.new(2026, 11, 5),
      "２０２６-１１-０５" => Date.new(2026, 11, 5), " 2026-11-05 " => Date.new(2026, 11, 5) }.each do |input, expected|
      OrderLog.where(mno: @order.mno).delete_all
      result = record(%w[105], input)
      if expected
        assert result.success?, input
        assert_equal expected, result.date, input
      else
        assert_not result.success?, input
      end
    end
  end

  test "nothing checked is refused and nothing is added" do
    [ [], nil, [ "" ], %w[abc] ].each do |kubuns|
      result = record(kubuns, "2026-11-12")
      assert_not result.success?, kubuns.inspect
      assert_equal "日付を登録する項目にチェックを入れてください。", result.error
    end
    assert_empty logs
  end

  test "a wrong date is refused and nothing is added" do
    [ nil, "", "  ", "abc", "2026-13-01", "2026-02-30", "26-11-12", "2026/11", "1800-01-01", "2200-01-01" ].each do |input|
      result = record(%w[105], input)
      assert_not result.success?, input.inspect
      assert_match(/日付を入力してください/, result.error)
    end
    assert_empty logs
  end

  test "only the manual kinds of the old checkboxes are accepted (not the request date, the automatic kinds or others)" do
    result = record(%w[101 1 2 3 4 5 6 7 108 0 999 105], "2026-11-12")
    assert result.success?
    assert_equal [ 105 ], logs.map(&:first)
    assert_equal [ "請求書出力日" ], result.labels
  end

  test "the same item checked twice is recorded once" do
    record(%w[105 105], "2026-11-12")
    assert_equal [ 105 ], logs.map(&:first)
  end

  test "the records of other orders are not touched" do
    OrderLog.create!(tvalid: 1, mno: 202611002, kubun: 105, datelog: Date.new(2026, 1, 1))
    record(%w[105], "2026-11-12")
    assert_equal 1, OrderLog.where(mno: 202611002).count
  end
end
