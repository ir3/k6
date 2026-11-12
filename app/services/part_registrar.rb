# frozen_string_literal: true

# Ａ部品詳細入力（旧 npartsr.asp → partsreg7.asp）の、Ａ部品台帳への新規登録。
# 入力項目と、旧 partsreg7.asp と同じ入れ先:
#   部品コード → pcode / 形式 → form / 和文名称 → jname / 英文名称 → ename
#   単位 → 計測単位(munit。画面の初期値は 1) / 重量 → weightkg（空欄・数でなければ重量なし）
#   単価 → 新単価(newprice)と現行単価(price)の両方（空欄・数でなければ 0）
# 部品コードが決まっていれば登録できる（名称などは、あとから Ａ部品メンテナンスで登録できる）。
class PartRegistrar
  Result = Data.define(:part, :error) do
    def success? = error.nil?
  end

  TEXT_MAX_LENGTH = 255
  MUNIT_RANGE = 0..99_999
  PRICE_RANGE = 0..2_000_000_000
  WEIGHT_RANGE = 0.0..1_000_000.0

  # input: ActionController::Parameters でも Hash でもよい（キーは pcode form jname ename munit weightkg newprice）
  def initialize(input)
    @input = input
  end

  def call
    code = PartCode.normalize(@input[:pcode])
    error = PartCode.error_for(code)
    return failure(error) if error

    texts = {}
    { form: "形式", jname: "和文名称", ename: "英文名称" }.each do |field, label|
      text = clean(@input[field])
      return failure("#{label}は #{TEXT_MAX_LENGTH} 文字以内で入力してください。") if text.length > TEXT_MAX_LENGTH

      texts[field] = text.presence
    end

    munit = read_integer(@input[:munit], MUNIT_RANGE, blank: nil)
    return failure("単位は #{MUNIT_RANGE.begin} から #{MUNIT_RANGE.end} の整数で入力してください。") if munit == :invalid

    weight = read_weight(@input[:weightkg])
    return failure("重量は #{WEIGHT_RANGE.begin.to_i} から #{WEIGHT_RANGE.end.to_i} の数で入力してください。") if weight == :invalid

    price = read_integer(@input[:newprice], PRICE_RANGE, blank: 0)
    return failure("単価は #{PRICE_RANGE.begin} から #{PRICE_RANGE.end} の整数で入力してください。") if price == :invalid

    part = Part.create!(texts.merge(pcode: code, munit: munit, weightkg: weight, newprice: price, price: price))
    Result.new(part: part, error: nil)
  end

  private

  # 前後の空白(全角を含む)を除く
  def clean(raw) = raw.to_s.gsub(/\A[[:space:]]+|[[:space:]]+\z/, "")

  # 空欄は blank、整数でないか範囲外なら :invalid
  def read_integer(raw, range, blank:)
    return blank if raw.to_s.strip.empty?

    IntegerInput.parse(raw, range) || :invalid
  end

  # 空欄は nil（重量なし）、数でなければ :invalid
  def read_weight(raw)
    text = raw.to_s.unicode_normalize(:nfkc).strip
    return nil if text.empty?

    weight = text.match?(/\A\d+(\.\d+)?\z/) ? text.to_f : nil
    weight && WEIGHT_RANGE.cover?(weight) ? weight : :invalid
  end

  def failure(message) = Result.new(part: nil, error: message)
end
