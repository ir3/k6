# frozen_string_literal: true

# Ｂ部品メンテナンス（旧 hiteijomente.asp）の、KE部品の1項目の登録
# （asp/kepartsedits=寸法 / kepartseditt=形式 / kepricereg=参考単価（新販売単価） / hnpartsb=備考 相当。
#  ItemNo・名称・計測単位・重量は、旧ASPでは動いていなかったので、ボタンの名前どおり該当の列を更新する）。
# 画面のフォームは1項目ずつ送るので、1回に1項目だけ受け付ける。部品コードはここでは変えない。
class KepartEditor
  Result = Data.define(:label, :error) do
    def success? = error.nil?
  end

  LABELS = {
    size: "寸法", form: "形式", itemno: "ItemNo", jname: "和文名称", ename: "英文名称",
    munit: "計測単位", weightkg: "重量", newprice: "参考単価", comment: "備考"
  }.freeze
  # 旧Accessの列の長さ（寸法=50、ItemNo=12。名称・形式・備考は255）
  TEXT_MAX_LENGTH = { size: 50, form: 255, itemno: 12, jname: 255, ename: 255, comment: 255 }.freeze
  INTEGER_RANGES = { munit: 0..99_999, newprice: 0..2_000_000_000 }.freeze
  WEIGHT_RANGE = 0.0..1_000_000.0

  def initialize(kepart, field, value)
    @kepart = kepart
    # 画面から来た文字列を、勝手に Symbol にしない（登録できる項目だけを探す）
    @field = LABELS.keys.find { |key| key.to_s == field.to_s }
    @value = value
  end

  def call
    return Result.new(label: nil, error: "登録する項目がありません。") unless @field

    label = LABELS.fetch(@field)
    if INTEGER_RANGES.key?(@field)
      save_integer(label)
    elsif @field == :weightkg
      save_weight(label)
    else
      save_text(label)
    end
  end

  private

  def save_integer(label)
    range = INTEGER_RANGES.fetch(@field)
    number = IntegerInput.parse(@value, range)
    return failure(label, "#{label}は #{range.begin} から #{range.end} の整数で入力してください。") unless number

    @kepart.update!(@field => number)
    success(label)
  end

  # 重量は小数も受け付ける。空欄にすると消去する（重量が無い部品が多い）
  def save_weight(label)
    raw = @value.to_s.unicode_normalize(:nfkc).strip
    if raw.empty?
      @kepart.update!(weightkg: nil)
      return success(label)
    end

    weight = raw.match?(/\A\d+(\.\d+)?\z/) ? raw.to_f : nil
    unless weight && WEIGHT_RANGE.cover?(weight)
      return failure(label, "#{label}は #{WEIGHT_RANGE.begin.to_i} から #{WEIGHT_RANGE.end.to_i} の数で入力してください（空欄にすると消去します）。")
    end

    @kepart.update!(weightkg: weight)
    success(label)
  end

  def save_text(label)
    # 前後の空白(全角を含む)を除く。空にすると消去する
    text = @value.to_s.gsub(/\A[[:space:]]+|[[:space:]]+\z/, "")
    max = TEXT_MAX_LENGTH.fetch(@field)
    return failure(label, "#{label}は #{max} 文字以内で入力してください。") if text.length > max

    @kepart.update!(@field => text.presence)
    success(label)
  end

  def success(label) = Result.new(label: label, error: nil)

  def failure(label, message) = Result.new(label: label, error: message)
end
