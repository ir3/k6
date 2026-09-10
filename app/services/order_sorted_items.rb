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
    :code, :itemno, :name, :info, :rate, :qty, :unit, :totalweight, :unitpd, :amount, :kzaiko,
    keyword_init: true
  )

  def self.for(order)
    new(order).items
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

    Item.new(
      sno: orderpart.sno, source: :orderpart, record: orderpart, part: part, part_source: (part ? part_source : nil),
      code: orderpart.partno, itemno: orderpart.itemno, name: part&.jname, info: orderpart.info,
      rate: orderpart.irate, qty: orderpart.qty, unit: orderpart.unit.presence || part&.sel_unit,
      totalweight: orderpart.totalweight, unitpd: orderpart.unitpd,
      amount: (orderpart.irate.to_f * orderpart.qty.to_f * orderpart.unitpd.to_f).round,
      kzaiko: orderpart.kzaiko
    )
  end

  def build_n_orderpart_item(n_orderpart)
    Item.new(
      sno: n_orderpart.sno, source: :n_orderpart, record: n_orderpart, part: nil, part_source: nil,
      code: nil, itemno: n_orderpart.itemno, name: n_orderpart.partsname, info: n_orderpart.info,
      rate: n_orderpart.rate, qty: n_orderpart.qty, unit: nil,
      totalweight: n_orderpart.weight, unitpd: n_orderpart.unitpd,
      amount: n_orderpart.totala.to_i,
      kzaiko: nil
    )
  end
end
