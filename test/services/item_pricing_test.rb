# frozen_string_literal: true

require "test_helper"

# 注文明細の単価・金額の求め方(旧partsin.asp)のテスト
class ItemPricingTest < ActiveSupport::TestCase
  def compute(unitpd:, rate:, qty:, bqty: 0, sel: nil)
    ItemPricing.compute(unitpd: unitpd, rate: rate, qty: qty, bqty: bqty, sel: sel)
  end

  test "掛け率1は単価を定価のまま、丸めない" do
    result = compute(unitpd: 1234, rate: 1.0, qty: 2)
    assert_equal [ 1234, 2468 ], [ result.price, result.amount ]
  end

  test "掛け率1以外は定価×掛け率を切り上げまるめする(1万円未満は10円単位)" do
    result = compute(unitpd: 1234, rate: 1.1, qty: 2)
    assert_equal [ 1360, 2720 ], [ result.price, result.amount ]
  end

  test "切り上げの単位は金額に応じて10円・100円・1000円・1万円" do
    assert_equal 104_000, compute(unitpd: 90_000, rate: 1.15, qty: 1).price # 103,500 → 1000円単位
    assert_equal 1_200_000, compute(unitpd: 1_000_000, rate: 1.2, qty: 1).price # 割り切れるときはそのまま
    assert_equal 1_220_000, compute(unitpd: 1_100_050, rate: 1.1, qty: 1).price # 1,210,055 → 1万円単位
  end

  test "掛け率0は1として扱い、定価を切り上げまるめする" do
    assert_equal 1240, compute(unitpd: 1234, rate: 0.0, qty: 1).price
  end

  test "バラ売りは数量がバラ数量、単価はバラ単価、金額はバラ数量×バラ単価" do
    result = compute(unitpd: 1030, rate: 1.0, qty: 1, bqty: 12, sel: "10")
    assert_equal [ 12, 103, 1236, true ], [ result.qty, result.price, result.amount, result.bulk ]
  end

  test "販売単位が数字でなければバラ数量があってもバラ売りにしない" do
    assert_equal false, compute(unitpd: 1030, rate: 1.0, qty: 1, bqty: 12, sel: "SET").bulk
  end

  test "A部品の掛け率は注文のA部品掛け率を使う" do
    order = Order.new(irate: 1.2)
    assert_equal 1.2, ItemPricing.effective_rate(order, :part, 1.0)
  end

  test "B部品は個別掛け率が1より大きければそれ、無ければ注文のB部品共通掛け率(0は1)" do
    order = Order.new(irate: 1.2, irate2: 1.5)
    assert_equal 1.3, ItemPricing.effective_rate(order, :kepart, 1.3)
    assert_equal 1.5, ItemPricing.effective_rate(order, :kepart, 1.0)
    assert_equal 1.0, ItemPricing.effective_rate(Order.new(irate: 1.2, irate2: 0.0), :kepart, 0.0)
  end

  test "部品番号無は個別掛け率、無ければ注文のB部品共通掛け率で、切り上げまるめする" do
    n_orderpart = NOrderpart.new(unitpd: 108_000, rate: 1.2, qty: 1)
    result = ItemPricing.for_n_orderpart(n_orderpart, fallback_rate: 0.0)
    assert_equal [ 130_000, 130_000 ], [ result.price, result.amount ]

    fallback = ItemPricing.for_n_orderpart(NOrderpart.new(unitpd: 1000, rate: 0.0, qty: 3), fallback_rate: 1.5)
    assert_equal [ 1500, 4500 ], [ fallback.price, fallback.amount ]

    no_rate = ItemPricing.for_n_orderpart(NOrderpart.new(unitpd: 1000, rate: 0.0, qty: 3), fallback_rate: 0.0)
    assert_equal [ 1000, 3000 ], [ no_rate.price, no_rate.amount ]
  end
end
