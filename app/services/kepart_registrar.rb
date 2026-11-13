# frozen_string_literal: true

# Ｂ部品の新規登録。KE部品台帳（keparts）に1行と、在庫台帳Ｂ（stockbs）に1行を、同時に登録する。
# 登録の元によって、旧ASPの入れ先が違うので、source で分ける。
#
# source: :part（Ａ部品から作る。旧 hnpartsreg.asp → hpartsreg6.asp）
#   KE部品: 部品コード（末尾に「~」）・寸法・和文名称・英文名称・計測単位・重量・ItemNo・新単価と現行単価・CORDNo(2)
#   在庫台帳Ｂ: 部品・kind 0・入庫区分・入庫日付（数量が 1 以上のとき今日）・数量・単価
# source: :scratch（Ａ部品に無い部品コードから作る。旧 npartsr32.asp → partsreg44.asp）
#   KE部品: 部品コード・和文名称・英文名称（空欄のときは和文名称と同じ値）・計測単位・重量・ItemNo・新単価と現行単価・CORDNo(2)
#   在庫台帳Ｂ: 部品・kind 1・数量・単価（入庫区分と入庫日付は入れない。旧ASPは、数量欄の値を無視して常に 1 だった）
# どちらも、計測単位の空欄は 1、重量の空欄は 0、単価の空欄は 0 にする（旧ASPのとおり）。
# 登録済みの部品コードは断る（旧ASPは重複を調べず、同じ行が2つできた）。
#
# order: 注文部品詳細の「部品番号を入力して部品選択」から来たとき（Ａ部品にもＢ部品にも無い部品番号。旧 partsin32.asp → partsreg4.asp）。
#   在庫台帳Ｂには足さず、KE部品台帳と、その注文の明細（orderparts）に1行ずつ足す。
#   明細は、数量 = 数量欄、単価 = 単価欄、ItemNo = 画面の値、CORDNo = 2、並び順は自動付番。
#   k6 の明細の決まりどおり、合計金額 = 単価 × 数量、合計重量 = 1個あたりの重量 × 数量にする
#   （旧 partsreg4.asp は合計金額に単価だけを入れたが、数量を変えると、この決まりで取り直される）。
#   数量の空欄は 1（画面の初期値）、重量の空欄は重量なし（旧 partsreg4.asp は、数でなければ重量の列を入れなかった）
class KepartRegistrar
  # orderpart: order を渡したときに足した、注文の明細（それ以外は nil）
  Result = Data.define(:kepart, :error, :orderpart) do
    def initialize(kepart:, error:, orderpart: nil) = super

    def success? = error.nil?
  end

  SOURCES = %i[part scratch].freeze
  CORDNO = "2"
  SIZE_MAX = 50
  ITEMNO_MAX = 12
  NAME_MAX = 255
  MUNIT_RANGE = 0..99_999
  NUM_RANGE = 0..999_999
  PRICE_RANGE = 0..2_000_000_000
  WEIGHT_RANGE = 0.0..1_000_000.0
  DEFAULT_IKUBUN = 1

  # Ａ部品から作るときの、画面の入力欄の初期値（旧 hnpartsreg.asp）。
  # 部品コードは末尾に「~」、計測単位はＡ部品の販売単位（数字のときだけ。無いか文字なら 1）、数量 1、ItemNo 0
  def self.defaults_from(part)
    unit = part.sel_unit.to_s.strip
    {
      pcode: "#{part.pcode}~", jname: part.jname, ename: part.ename,
      munit: unit.match?(/\A\d+\z/) ? unit : "1",
      num: "1", weightkg: part.weightkg, newprice: part.newprice, itemno: "0", ikubun: DEFAULT_IKUBUN.to_s
    }
  end

  # input: ActionController::Parameters でも Hash でもよい
  # （キーは pcode size jname ename munit num weightkg newprice itemno ikubun。:scratch では size ikubun は使わない）
  def initialize(input, source:, order: nil)
    raise ArgumentError, "source は #{SOURCES.inspect} のどちらか" unless SOURCES.include?(source)

    @input = input
    @source = source
    @order = order
  end

  def call
    return failure("管理番号がない注文には部品を追加できません。") if @order && @order.mno.blank?

    code = PartCode.normalize(@input[:pcode])
    error = code_error(code)
    return failure(error) if error

    texts = read_texts
    return failure(texts) if texts.is_a?(String)

    munit = read_integer(@input[:munit], MUNIT_RANGE, blank: 1)
    return failure("計測単位は #{MUNIT_RANGE.begin} から #{MUNIT_RANGE.end} の整数で入力してください。") if munit == :invalid

    num = read_integer(@input[:num], NUM_RANGE, blank: @order ? 1 : 0)
    return failure("数量は #{NUM_RANGE.begin} から #{NUM_RANGE.end} の整数で入力してください。") if num == :invalid

    weight = read_weight(@input[:weightkg])
    return failure("重量は #{WEIGHT_RANGE.begin.to_i} から #{WEIGHT_RANGE.end.to_i} の数で入力してください。") if weight == :invalid

    price = read_integer(@input[:newprice], PRICE_RANGE, blank: 0)
    return failure("単価は #{PRICE_RANGE.begin} から #{PRICE_RANGE.end} の整数で入力してください。") if price == :invalid

    ikubun = read_integer(@input[:ikubun], 1..4, blank: DEFAULT_IKUBUN)
    return failure("入庫区分を選んでください。") if ikubun == :invalid && @source == :part && !@order

    kepart = row = nil
    Kepart.transaction do
      kepart = Kepart.create!(texts.merge(pcode: code, munit: munit, weightkg: weight, newprice: price, price: price, cordno: CORDNO))
      if @order
        row = create_order_row(kepart, num, price)
      else
        Stockb.create!(stock_attributes(code, num, price, ikubun))
      end
    end
    Result.new(kepart: kepart, error: nil, orderpart: row)
  end

  private

  def code_error(code)
    return "部品コードを入力してください。" if code.empty?
    return "部品コードは #{PartCode::MAX_LENGTH} 文字以内で入力してください。" if code.length > PartCode::MAX_LENGTH
    return "部品コードは、英数字と記号だけで入力してください。" unless code.match?(/\A[!-~]+\z/)
    return "部品コード「#{code}」は、すでにＢ部品台帳にあります。" if Kepart.exists?([ "UPPER(pcode) = ?", code ])

    nil
  end

  # 文字の項目を読む。長すぎるときは、メッセージ（String）を返す
  def read_texts
    fields = { jname: [ "和文名称", NAME_MAX ], itemno: [ "ItemNo", ITEMNO_MAX ] }
    fields[:ename] = [ "英文名称", NAME_MAX ]
    fields[:size] = [ "寸法", SIZE_MAX ] if @source == :part

    texts = {}
    fields.each do |field, (label, max)|
      text = clean(@input[field])
      return "#{label}は #{max} 文字以内で入力してください。" if text.length > max

      texts[field] = text.presence
    end
    # Ａ部品に無い部品コードから作るとき、旧 partsreg44.asp は、名称を和文名称と英文名称の両方に入れた。
    # 今は英文名称も入力できる。英文名称が空欄のときだけ、従来どおり和文名称を英文名称にも入れる
    texts[:ename] ||= texts[:jname] if @source == :scratch
    texts
  end

  def stock_attributes(code, num, price, ikubun)
    if @source == :part
      { partno: code, kind: 0, ikubun: ikubun, indate: (Date.current if num.positive?), num: num, irprice: price }
    else
      { partno: code, kind: 1, num: num, irprice: price }
    end
  end

  # 前後の空白(全角を含む)を除く
  def clean(raw) = raw.to_s.gsub(/\A[[:space:]]+|[[:space:]]+\z/, "")

  # 空欄は blank、整数でないか範囲外なら :invalid
  def read_integer(raw, range, blank:)
    return blank if raw.to_s.strip.empty?

    IntegerInput.parse(raw, range) || :invalid
  end

  # 空欄は 0.0（旧ASPは、数でなければ 0）、数でないか範囲外なら :invalid。
  # 注文から来たときの空欄は、重量なし（nil。旧 partsreg4.asp は、数でなければ重量の列を入れなかった）
  def read_weight(raw)
    text = raw.to_s.unicode_normalize(:nfkc).strip
    return (@order ? nil : 0.0) if text.empty?

    weight = text.match?(/\A\d+(\.\d+)?\z/) ? text.to_f : nil
    weight && WEIGHT_RANGE.cover?(weight) ? weight : :invalid
  end

  # 注文の明細に、登録したＢ部品を1行足す（数量・単価は画面の値。並び順は注文の最後に続ける）
  def create_order_row(kepart, qty, price)
    unit_weight = OrderPartAdder.unit_weight(kepart)
    Orderpart.create!(
      mno: @order.mno, sno: @order.next_part_sno, partno: kepart.pcode,
      itemno: kepart.itemno.presence || OrderPartAdder::DEFAULT_ITEMNO, cordno: CORDNO,
      qty: qty, unitpd: price, irate: @order.irate || 1.0, totala: price * qty,
      unitweight: unit_weight, totalweight: (unit_weight * qty).round(3)
    )
  end

  def failure(message) = Result.new(kepart: nil, error: message)
end
