# frozen_string_literal: true

# 在庫メンテナンス画面の「この部品の入出荷状況」。部品の在庫台帳の行を、更新の新しい順に並べる。
# 出荷先・船名は、取引No がある行は取引台帳の注文から、無い行(や削除済みの注文)は台帳の行のメモから出す。
class StockHistory
  # 当初表示する件数（旧 zaikomente.asp は「当初表示件数は21件に。全件要求で全件に」）
  INITIAL_LIMIT = 21

  Row = Data.define(
    :date, :company, :shipname, :price, :ordered, :in_qty, :in_amount, :out_qty, :out_amount,
    :note, :mno, :order, :updated_at
  )

  def initialize(partno, all: false)
    @partno = partno
    @all = all
  end

  def total
    @total ||= scope.count
  end

  def truncated?
    !@all && total > INITIAL_LIMIT
  end

  def rows
    @rows ||= begin
      stocks = @all ? scope.to_a : scope.limit(INITIAL_LIMIT).to_a
      orders = orders_by_mno(stocks)
      companies = companies_by_adlist_no(orders.values)
      stocks.map { |stock| build_row(stock, orders[stock.mno], companies) }
    end
  end

  private

  # 取引No順ではなく、旧ASPと同じく更新の新しい順（同時刻は台帳の番号の大きい順）
  def scope
    Stock.of_part(@partno).where(deleted_at: nil).reorder(updated_at: :desc, id: :desc)
  end

  def orders_by_mno(stocks)
    mnos = stocks.filter_map { |stock| stock.mno if stock.mno.to_i.positive? }.uniq
    Order.where(mno: mnos).index_by(&:mno)
  end

  def companies_by_adlist_no(orders)
    Adlist.where(no: orders.map { |order| order.adlist_id.to_s }.uniq).index_by(&:no)
  end

  def build_row(stock, order, companies)
    num = stock.num.to_i
    price = stock.irprice.to_i
    adlist = order && companies[order.adlist_id.to_s]
    Row.new(
      date: stock.indate || stock.outdate || stock.updated_at.to_date,
      company: order ? (adlist&.company.presence || adlist&.name) : stock.cname,
      shipname: order ? order.shipname : stock.sname,
      price: price, ordered: stock.onum,
      # 入庫は正、出庫は負。数量0(発注だけの行)は入庫にも出庫にも出さない
      in_qty: (num if num.positive?), in_amount: (price * num if num.positive?),
      out_qty: (-num if num.negative?), out_amount: (price * -num if num.negative?),
      note: [ *stock.kind_labels, stock.memo ].compact_blank.join("　"),
      mno: stock.mno.to_i.positive? ? stock.mno : nil, order: order, updated_at: stock.updated_at
    )
  end
end
