# frozen_string_literal: true

# 注文明細の「数量・単価・金額」の求め方。注文部品詳細画面・並び替え後表示・見積書・請求書・納品書の
# すべてがこれを使う(旧asp/partsin.asp、見積テーブルのNprice・TotalB相当)。
#
# - 掛け率が1: 単価は定価(UnitPD)のまま、金額は 定価×数量(丸めなし)。
# - 掛け率が1以外: 単価 = 定価×掛け率を切り上げまるめしたもの。切り上げまるめは旧asp/include/fsysfunc.asp
#   のkmarume(上位3桁に、1円の桁は常に0)で、PriceRounding.round_upと同じ。掛け率0は1扱い。
#   金額は 切り上げ後の単価×数量。
# - バラ売り(販売単位が数字で、バラ数量が入っている): 数量はバラ数量、単価はバラ単価(上の単価÷販売単位)、
#   金額は バラ数量×単価÷販売単位。
# - 部品番号無(NOrderpart): 明細の個別掛け率(0より大きいとき)、無ければ注文のB部品共通掛け率(irate2)を使い、
#   掛け率が0より大きければ単価に掛ける(掛け率1は丸めなし、それ以外は切り上げまるめ)。金額は 単価×数量。
module ItemPricing
  Result = Struct.new(:qty, :price, :amount, :bulk, keyword_init: true)

  # 部品番号ありの明細に使う掛け率(旧partsin.aspの規則)。明細(Orderpart)に持っている掛け率ではなく、
  # - A部品(部品台帳にある部品): 注文のA部品掛け率(Order#irate)
  # - B部品(KE部品台帳にある部品): 明細の個別掛け率が1より大きければそれ、無ければ注文のB部品共通掛け率(Order#irate2。0は1扱い)
  # - どちらにも無い部品: 明細の掛け率
  # part_sourceはOrderSortedItemsと同じ :part / :kepart / nil。
  def self.effective_rate(order, part_source, row_rate)
    case part_source
    when :part
      order&.irate.nil? ? 1.0 : order.irate.to_f
    when :kepart
      return row_rate.to_f if row_rate.to_f > 1.0

      common = order&.irate2.to_f
      common.zero? ? 1.0 : common
    else
      row_rate.to_f
    end
  end

  # itemはOrderSortedItems::Item
  def self.for(item)
    if item.source == :orderpart
      for_orderpart(item.record, sel: item.unit, rate: item.rate)
    else
      Result.new(qty: format_number(item.qty), price: (item.price || item.unitpd).to_i, amount: item.amount.to_i, bulk: false)
    end
  end

  # orderpartはOrderpart、selは販売単位(明細のunit、無ければ部品台帳のsel_unit)、rateは effective_rate で求めた掛け率
  # (省略時は明細の掛け率)
  def self.for_orderpart(orderpart, sel: nil, rate: nil)
    compute(unitpd: orderpart.unitpd, rate: rate || orderpart.irate, qty: orderpart.qty, bqty: orderpart.bqty,
            sel: sel.presence || orderpart.unit)
  end

  # n_orderpartはNOrderpart、fallback_rateは注文のB部品共通掛け率(Order#irate2)。旧partsin.aspの部品番号無の計算
  def self.for_n_orderpart(n_orderpart, fallback_rate: nil)
    rate = n_orderpart.rate.to_f.positive? ? n_orderpart.rate.to_f : fallback_rate.to_f
    price = n_orderpart.unitpd.to_f
    if rate.positive?
      price *= rate
      price = rate == 1.0 ? price.round : PriceRounding.round_up(price.round(6))
    end
    Result.new(qty: format_number(n_orderpart.qty), price: price.round, amount: (price * n_orderpart.qty.to_f).round, bulk: false)
  end

  def self.compute(unitpd:, rate:, qty:, bqty:, sel:)
    unitpd = unitpd.to_f
    rate = rate.to_f
    qty = qty.to_f

    if rate == 1.0
      price = unitpd.round
      amount = (unitpd * qty).round
    else
      effective_rate = rate.zero? ? 1.0 : rate
      price = PriceRounding.round_up((unitpd * effective_rate).round(6))
      amount = (price * qty).round
    end

    sel = sel.to_s.strip
    if bqty.to_i.positive? && SalesUnit.numeric?(sel) && sel.to_f.positive?
      each_price = price / sel.to_f
      return Result.new(qty: bqty.to_i, price: each_price.round, amount: (bqty.to_i * each_price).round, bulk: true)
    end

    Result.new(qty: format_number(qty), price: price, amount: amount, bulk: false)
  end

  def self.format_number(value)
    value.to_f == value.to_i ? value.to_i : value
  end
end
