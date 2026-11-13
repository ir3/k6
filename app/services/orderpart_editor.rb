# frozen_string_literal: true

# 注文部品詳細編集画面からの1項目の登録（asp/partseditA / partseditI / partseditB / partsreg2 / partsedit22P /
# partsedit22K / partnamesedit と partsregbara 相当）。画面のフォームは1項目ずつ送るので、1回に1項目だけ受け付ける。
class OrderpartEditor
  Result = Data.define(:label, :error) do
    def success? = error.nil?
  end

  # unitpd（時価）・irate（個別掛け率）・jname / ename（Ｂ部品台帳の名称）は、Ｂ部品の明細（Ｂ部品詳細編集）だけ
  LABELS = { sno: "順", itemno: "ItemNo", info: "備考", qty: "数量", bqty: "バラ売り数量",
             unitpd: "時価", irate: "個別掛け率", jname: "和文名称", ename: "英文名称" }.freeze
  INTEGER_RANGES = { sno: -99_999..99_999, qty: 0..999_999, bqty: 0..999_999, unitpd: 0..2_000_000_000 }.freeze
  TEXT_MAX_LENGTH = { itemno: 30, info: 100 }.freeze
  B_PART_ONLY = %i[unitpd irate jname ename].freeze
  # 個別掛け率は、数（小数も可）。旧 partsin22.asp は、1000 より大きい値を 1 として扱った
  RATE_FORMAT = /\A\d+(\.\d+)?\z/
  RATE_MAX = 1000.0

  def initialize(orderpart, input)
    @orderpart = orderpart
    @input = input.to_h.symbolize_keys
  end

  def call
    field = LABELS.keys.find { |key| @input.key?(key) }
    return failure(nil, "登録する項目がありません。") unless field

    label = LABELS.fetch(field)
    # 時価・個別掛け率・名称を変えられるのは、Ｂ部品（KE部品台帳にあって、Ａ部品に無い部品）の明細だけ。
    # Ｂ部品は時価なので、旧 partsedit22P.asp（Ｂ部品単価変更）と同じく、取引ごとに明細の時価を入力する。
    # Ａ部品の単価は、部品台帳（新単価）から入るので、ここでは変えない。
    # 名称は、旧 partnamesedit.asp（Ｂ部品名称変更）と同じく、明細ではなく、Ｂ部品台帳（KE部品台帳）の名称を変える
    return failure(label, "#{label}を変えられるのは、Ｂ部品の明細だけです。") if B_PART_ONLY.include?(field) && !b_part?

    if INTEGER_RANGES.key?(field)
      save_integer(field, label)
    elsif field == :irate
      save_rate(label)
    elsif %i[jname ename].include?(field)
      save_master_name(field, label)
    else
      save_text(field, label)
    end
  end

  private

  def save_integer(field, label)
    range = INTEGER_RANGES.fetch(field)
    # 全角で入力されても受け付ける（ASPは英数字入力枠でIME無効化していた）
    raw = @input[field].to_s.unicode_normalize(:nfkc).strip
    unless raw.match?(/\A-?\d+\z/) && range.cover?(raw.to_i)
      return failure(label, "#{label}は #{range.begin} から #{range.end} の整数で入力してください。")
    end

    case field
    when :qty then @orderpart.change_qty!(raw.to_i)
    when :unitpd then @orderpart.change_unitpd!(raw.to_i)
    else @orderpart.update!(field => raw.to_i)
    end
    Result.new(label: label, error: nil)
  end

  def save_text(field, label)
    # 前後の空白(全角を含む)を除く。空にすると消去する
    text = @input[field].to_s.gsub(/\A[[:space:]]+|[[:space:]]+\z/, "")
    max = TEXT_MAX_LENGTH.fetch(field)
    return failure(label, "#{label}は #{max} 文字以内で入力してください。") if text.length > max

    @orderpart.update!(field => text.presence)
    Result.new(label: label, error: nil)
  end

  # 個別掛け率（旧 partsedit22K.asp）。明細の掛け率を変える。空欄・数でない値・大きすぎる値は断る
  def save_rate(label)
    raw = @input[:irate].to_s.unicode_normalize(:nfkc).strip
    unless raw.match?(RATE_FORMAT) && raw.to_f <= RATE_MAX
      return failure(label, "#{label}は 0 から #{RATE_MAX.to_i} の数で入力してください。")
    end

    @orderpart.update!(irate: raw.to_f)
    Result.new(label: label, error: nil)
  end

  # Ｂ部品台帳（KE部品台帳）の和文名称・英文名称を変える（旧 partnamesedit.asp）
  def save_master_name(field, label)
    result = KepartEditor.new(@orderpart.master_part, field, @input[field]).call
    Result.new(label: label, error: result.error)
  end

  # 部品台帳（Ａ部品）に無く、KE部品台帳（Ｂ部品）にある部品の明細か
  def b_part?
    @orderpart.master_part.is_a?(Kepart)
  end

  def failure(label, message)
    Result.new(label: label, error: message)
  end
end
