# frozen_string_literal: true

# 注文部品詳細画面の「並び替え後表示」で使う、Orderpart(部品明細)とNOrderpart(部品番号無)を
# 「順(SNo)」で一本化した明細一覧。
#
# 旧ASP(asp/jutyu111.asp)は「見積」という一時テーブルに、部品番号あり/無を順で
# あらかじめ一本化したものを持っていたが、そのテーブルはMNo列を持たず注文と紐付かない
# ワークテーブルだったため使わず、都度この場でOrderpart+NOrderpartをマージして代替する。
# orders#sorted画面の一覧表示と、JuchuMemoReport(受注メモ)等の帳票明細の両方で共有する。
class OrderSortedItems
  Item = Struct.new(
    :sno, :source, :record, :part, :part_source,
    :code, :itemno, :name, :info, :rate, :qty, :unit, :totalweight, :unitpd, :amount, :kzaiko, :price,
    keyword_init: true
  )

  def self.for(order)
    new(order).items
  end

  # 印刷する明細。表示する数量(バラ売りはバラ数量)が0のものを除いて、上に詰める(受注メモ・請求書・納品書・
  # 出荷案内書・物品受領書)。並び替え後表示の一覧や見積書は、数量0も含む forを使う。
  def self.printable(order)
    self.for(order).reject { |item| ItemPricing.for(item).qty.to_f.zero? }
  end

  def initialize(order)
    @order = order
  end

  def items
    (orderpart_items + n_orderpart_items).sort_by { |item| item.sno.to_i }
  end

  private

  def orderpart_items
    Orderpart.where(mno: @order.mno).map { |orderpart| build_orderpart_item(orderpart) }
  end

  def n_orderpart_items
    # tvalid=0(無効)は除外する(_n_orderpart_row.html.hamlの取り消し線表示と同じ扱い)。
    NOrderpart.where(mno: @order.mno).where.not(tvalid: 0).map { |n_orderpart| build_n_orderpart_item(n_orderpart) }
  end

  def build_orderpart_item(orderpart)
    part = Part.find_by(pcode: orderpart.partno)
    part_source = :part
    if part.nil?
      part = Kepart.find_by(pcode: orderpart.partno)
      part_source = :kepart
    end

    # 掛け率は旧partsin.aspと同じく、A部品は注文のA部品掛け率、B部品は個別掛け率か注文のB部品共通掛け率
    rate = ItemPricing.effective_rate(@order, part_source, orderpart.irate)
    sel = orderpart.unit.presence || part&.sel_unit
    Item.new(
      sno: orderpart.sno, source: :orderpart, record: orderpart, part: part, part_source: (part ? part_source : nil),
      code: orderpart.partno, itemno: orderpart.itemno, name: part&.jname, info: orderpart.info,
      rate: rate, qty: orderpart.qty, unit: sel,
      totalweight: orderpart.totalweight, unitpd: orderpart.unitpd,
      amount: ItemPricing.for_orderpart(orderpart, sel: sel, rate: rate).amount,
      kzaiko: orderpart.kzaiko
    )
  end

  def build_n_orderpart_item(n_orderpart)
    # 単価・金額は旧partsin.aspの部品番号無と同じ求め方(掛け率を掛けて切り上げまるめ)
    pricing = ItemPricing.for_n_orderpart(n_orderpart, fallback_rate: @order.irate2)
    Item.new(
      sno: n_orderpart.sno, source: :n_orderpart, record: n_orderpart, part: nil, part_source: nil,
      code: nil, itemno: n_orderpart.itemno, name: n_orderpart.partsname, info: n_orderpart.info,
      rate: n_orderpart.rate, qty: n_orderpart.qty, unit: nil,
      totalweight: n_orderpart.weight, unitpd: n_orderpart.unitpd,
      amount: pricing.amount, price: pricing.price,
      kzaiko: nil
    )
  end
end
