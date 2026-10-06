# frozen_string_literal: true

# 注文部品詳細編集画面からの1項目の登録（asp/partseditA / partseditI / partseditB / partsreg2 と
# partsregbara 相当）。画面のフォームは1項目ずつ送るので、1回に1項目だけ受け付ける。
class OrderpartEditor
  Result = Data.define(:label, :error) do
    def success? = error.nil?
  end

  LABELS = { sno: "順", itemno: "ItemNo", info: "備考", qty: "数量", bqty: "バラ売り数量" }.freeze
  INTEGER_RANGES = { sno: -99_999..99_999, qty: 0..999_999, bqty: 0..999_999 }.freeze
  TEXT_MAX_LENGTH = { itemno: 30, info: 100 }.freeze

  def initialize(orderpart, input)
    @orderpart = orderpart
    @input = input.to_h.symbolize_keys
  end

  def call
    field = LABELS.keys.find { |key| @input.key?(key) }
    return failure(nil, "登録する項目がありません。") unless field

    label = LABELS.fetch(field)
    if INTEGER_RANGES.key?(field)
      save_integer(field, label)
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

    field == :qty ? @orderpart.change_qty!(raw.to_i) : @orderpart.update!(field => raw.to_i)
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

  def failure(label, message)
    Result.new(label: label, error: message)
  end
end
