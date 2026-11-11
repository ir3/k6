# frozen_string_literal: true

# Ｂ部品在庫表示（旧 hzaikolist.asp → 中身は hzaikosel.asp）の一覧。部品ごとに在庫の増減を集計して並べる。
# Ａ部品の StockList のＢ部品版。
#
# 旧ASPは Access の保存済みクエリ v在庫現在値B を引いていた。その定義（MSysQueries）は次のとおり。
#   v在庫現在値B … 在庫台帳B INNER JOIN ke部品 ON 在庫台帳B.PartNo = ke部品.部品コード を PartNo ごとに Sum(Num)
# INNER JOIN なので、旧一覧に出るのは「ke部品(KE部品台帳)にある部品」だけ。在庫台帳Bにしか無い部品は出ない。
#
# 旧ASPの規則（hzaikosel.asp）:
# - 部品コードの一部（%…%）で絞る。在庫有り(zero=1)は在庫数が 0 より大きいものだけ
# - 検索の部品コードに「~」が入っているときは「~」付きの部品（寸法で表す部品）だけを、寸法の列つきで出す。
#   入っていないときは「~」の無い部品だけを、型式の列つきで出す
# - 部品コード順
# - 非表示(在庫非表示B)に設定された部品は出さない。ただし、k6 には B部品の非表示設定がまだ無い
#   （Access の 在庫非表示B は1件だけで、ke部品にも台帳にも無い部品なので、一覧には影響しない）
#
# 数量は Stockb.counted（削除済み・無効を除く）で数える。
class StockbList
  # second: 「型式」または「寸法」の列の値（検索に「~」があり、部品も「~」付きなら寸法）
  Row = Data.define(:id, :pcode, :second, :jname, :ename, :price, :sel_unit, :weightkg, :munit, :on_hand)

  TILDE = "~"

  # partno: 部品コードの一部（大文字小文字は区別しない）
  # in_stock: 在庫数が1以上の部品だけ（旧ASPの zero=1）
  def initialize(partno: nil, in_stock: false)
    @partno = partno.to_s.strip
    @in_stock = in_stock
  end

  # 2列目の見出し。「~」を含む検索のときは寸法、それ以外は型式
  def second_title
    tilde_search? ? "寸法" : "型式"
  end

  def rows
    totals = stock_totals
    parts.filter_map { |part| build_row(part, totals) }.sort_by { |row| row.pcode.to_s.upcase }
  end

  private

  def tilde_search?
    @partno.include?(TILDE)
  end

  # KE部品台帳の部品。部品コードの一部が指定されていれば絞る
  def parts
    scope = Kepart.all
    scope = scope.where("pcode LIKE ? ESCAPE '\\'", "%#{Kepart.sanitize_sql_like(@partno)}%") if @partno.present?
    scope.pluck(:id, :pcode, :form, :size, :jname, :ename, :newprice, :sel_unit, :weightkg, :munit)
  end

  # 部品コード(大文字)ごとの在庫数。
  # SQLでやるのは部品ごとの集計1回だけ（stockbs.partno にも keparts.pcode にも索引が無いので、
  # SQLで UPPER() 同士を突き合わせると遅い）。突き合わせはRubyのハッシュでする
  def stock_totals
    Stockb.counted.group(Arel.sql("UPPER(partno)"))
          .pluck(Arel.sql("UPPER(partno)"), Arel.sql("SUM(num)"))
          .to_h
  end

  def build_row(part, totals)
    id, pcode, form, size, jname, ename, price, sel_unit, weightkg, munit = part
    key = pcode.to_s.strip.upcase
    return unless totals.key?(key) # 在庫台帳Bに行が無い部品は出さない（INNER JOIN）
    return unless tilde_search? == key.include?(TILDE) # 「~」付きの部品は「~」を含む検索のときだけ、逆も同じ

    on_hand = totals[key]
    return if @in_stock && !on_hand.to_i.positive?

    Row.new(id: id, pcode: pcode, second: (tilde_search? ? size : form), jname: jname, ename: ename, price: price,
            sel_unit: sel_unit, weightkg: weightkg, munit: munit, on_hand: on_hand)
  end
end
