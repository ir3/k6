# frozen_string_literal: true

# Ａ部品在庫表示（旧 zaikolist.asp → 中身は zaikosel.asp）の一覧。部品ごとに在庫の増減を集計して並べる。
#
# 旧ASPは Access の保存済みクエリ v在庫現在値 / v発注記録 を引いていた。その定義（MSysQueries）は次のとおり。
#   v在庫現在値 … 在庫台帳 INNER JOIN 新潟部品 ON 在庫台帳.PartNo = 新潟部品.部品コード を PartNo ごとに Sum(Num)
#   v発注記録   … 在庫台帳を PartNo ごとに Sum(Onum)
# INNER JOIN なので、旧一覧に出るのは「部品台帳(新潟部品)にある部品」だけ。在庫台帳にしか無い部品は出ない。
#
# 数量は Stock.counted（削除済み・無効を除く）で数える。在庫メンテナンスの計算在庫数と同じにして、
# 一覧とメンテナンス画面で在庫数が食い違わないようにしている（旧ASPは全行の合計だが、
# 2026-11-10 の実データでは、その合計と食い違う部品は無かった）。
class StockList
  Row = Data.define(:pcode, :form, :jname, :ename, :price, :sel_unit, :weightkg, :munit,
                    :on_hand, :standard, :forecast, :ordered) do
    # 必要在庫は「標準在庫」＋「予測量」（旧ASPと同じ）
    def required = standard + forecast

    # 在庫数が必要在庫に足りない（画面では在庫数を赤く出す）。在庫数が空(NULL)のものは判定しない
    def short? = !on_hand.nil? && required > on_hand
  end

  # partno: 部品コードの一部（大文字小文字は区別しない）
  # in_stock: 在庫数が1以上の部品だけ（旧ASPの zero=1）
  def initialize(partno: nil, in_stock: false)
    @partno = partno.to_s.strip
    @in_stock = in_stock
  end

  def rows
    totals = stock_totals
    settings = stock_settings
    parts.filter_map { |part| build_row(part, totals, settings) }.sort_by { |row| row.pcode.upcase }
  end

  private

  # 部品台帳の部品。部品コードの一部が指定されていれば絞る
  def parts
    scope = Part.reorder(nil)
    scope = scope.where("pcode LIKE ? ESCAPE '\\'", "%#{Part.sanitize_sql_like(@partno)}%") if @partno.present?
    scope.pluck(:pcode, :form, :jname, :ename, :newprice, :sel_unit, :weightkg, :munit)
  end

  # 部品コード(大文字)ごとの [在庫数, 発注中]。
  # SQLでやるのは部品ごとの集計1回だけ。stocks.partno にも parts.pcode にも索引が無いので、
  # SQLで UPPER() 同士を突き合わせると遅い（数万行で分単位）。突き合わせはRubyのハッシュでする
  def stock_totals
    Stock.counted.group(Arel.sql("UPPER(partno)"))
         .pluck(Arel.sql("UPPER(partno)"), Arel.sql("SUM(num)"), Arel.sql("SUM(onum)"))
         .to_h { |key, on_hand, ordered| [ key, [ on_hand, ordered ] ] }
  end

  # 部品コード(大文字)ごとの在庫の設定（標準在庫・予測量・非表示）。登録時の大文字小文字や空白の揺れに備えてそろえる
  def stock_settings
    StockSetting.all.index_by { |setting| setting.partno.to_s.strip.upcase }
  end

  def build_row(part, totals, settings)
    pcode, form, jname, ename, price, sel_unit, weightkg, munit = part
    key = pcode.to_s.strip.upcase
    return unless totals.key?(key) # 在庫台帳に行が無い部品は出さない（INNER JOIN）

    on_hand, ordered = totals[key]
    setting = settings[key]
    return unless visible?(on_hand, setting)

    Row.new(pcode: pcode, form: form, jname: jname, ename: ename, price: price, sel_unit: sel_unit,
            weightkg: weightkg, munit: munit, on_hand: on_hand, ordered: ordered,
            standard: setting&.snum || 0, forecast: setting&.znum || 0)
  end

  # 在庫有り(zero=1)は在庫数が1以上だけで、非表示の設定は見ない。
  # それ以外は、非表示に設定された部品を除く（旧ASPと同じ）
  def visible?(on_hand, setting)
    return on_hand.to_i.positive? if @in_stock

    !setting&.hidden?
  end
end
