# frozen_string_literal: true

# Ａ部品メンテナンス（旧 partsmente.asp）の、Ａ部品の1項目の登録
# （旧 npartseditty / npartseditwa / npartsediten / npartseditunit / npartseditweight / npartsedit1 / npartsedit2 /
#  npartsb / npartsedit3 相当）。画面のフォームは1項目ずつ送るので、1回に1項目だけ受け付ける。
# 部品コードはここでは変えない（変えたいときは「新部品を複製」で新しい部品コードの部品を作る）。
# 旧部品番号は、部品台帳ではなく、在庫設定（stock_settings）に持つ。
class PartEditor
  Result = Data.define(:label, :error) do
    def success? = error.nil?
  end

  LABELS = {
    form: "形式", jname: "和文名称", ename: "英文名称", sel_unit: "販売単位", weightkg: "重量",
    newprice: "新単価", price: "現行単価", comment: "備考", opartno: "旧部品番号"
  }.freeze
  # 旧Accessの列の長さ（旧部品番号=16。そのほかは255）
  TEXT_MAX_LENGTH = { form: 255, jname: 255, ename: 255, sel_unit: 255, comment: 255, opartno: 16 }.freeze
  INTEGER_RANGES = { newprice: 0..2_000_000_000, price: 0..2_000_000_000 }.freeze
  WEIGHT_RANGE = 0.0..1_000_000.0

  def initialize(part, field, value)
    @part = part
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

    @part.update!(@field => number)
    success(label)
  end

  # 重量は小数も受け付ける。空欄にすると消去する（重量が無い部品がある）
  def save_weight(label)
    raw = @value.to_s.unicode_normalize(:nfkc).strip
    if raw.empty?
      @part.update!(weightkg: nil)
      return success(label)
    end

    weight = raw.match?(/\A\d+(\.\d+)?\z/) ? raw.to_f : nil
    unless weight && WEIGHT_RANGE.cover?(weight)
      return failure(label, "#{label}は #{WEIGHT_RANGE.begin.to_i} から #{WEIGHT_RANGE.end.to_i} の数で入力してください（空欄にすると消去します）。")
    end

    @part.update!(weightkg: weight)
    success(label)
  end

  def save_text(label)
    # 前後の空白(全角を含む)を除く。空にすると消去する
    text = @value.to_s.gsub(/\A[[:space:]]+|[[:space:]]+\z/, "")
    max = TEXT_MAX_LENGTH.fetch(@field)
    return failure(label, "#{label}は #{max} 文字以内で入力してください。") if text.length > max

    if @field == :opartno
      save_old_part_number(text)
    else
      @part.update!(@field => text.presence)
    end
    success(label)
  end

  # 旧部品番号（在庫設定の OPartsNo）。在庫設定の行が無く、空にするだけなら、行は作らない
  def save_old_part_number(text)
    setting = StockSetting.for_part(@part.pcode)
    return if text.empty? && setting.new_record?

    setting.update!(opartno: text.presence)
  end

  def success(label) = Result.new(label: label, error: nil)

  def failure(label, message) = Result.new(label: label, error: message)
end
