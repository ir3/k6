# frozen_string_literal: true

# 部品番号が不明な分を、部品名だけで仮登録する（asp/partsreg5.asp 相当）。
#
# 注文の「部品番号なし」の明細(NOrderpart: n_orderparts)に1行追加する。
# 数量・単価などは後から入力する前提で、partsreg5.asp は部品名しか登録していなかった。
# k6 のテーブルには DB の既定値が無いので、追加した行が表示も計算も壊れないように
# 有効(tvalid=1)・数量1・単価と掛け率と重量は0を入れる。
class OrderPartNameAdder
  # 部品名の最大長（実データの最長は50文字）
  MAX_LENGTH = 100

  Result = Data.define(:row, :error) do
    def success? = error.nil?
  end

  def initialize(order, input)
    @order = order
    @input = input
  end

  def call
    return failure("管理番号がない注文には部品を追加できません。") if @order.mno.blank?

    name = normalize(@input)
    return failure("部品名を入力してください。") if name.empty?
    return failure("部品名は#{MAX_LENGTH}文字以内で入力してください。") if name.length > MAX_LENGTH

    row = NOrderpart.create!(
      mno: @order.mno, sno: @order.next_part_sno, partsname: name,
      qty: 1, rate: 0, unitpd: 0, totala: 0, weight: 0, tvalid: 1
    )
    Result.new(row: row, error: nil)
  end

  private

  # 改行やタブは空白にし、前後の空白（全角空白を含む）を除く。
  # 部品名の中の空白や半角カナ・全角はそのまま残す（実データの部品名はそのままの表記）。
  def normalize(input)
    input.to_s.gsub(/[\r\n\t]+/, " ").gsub(/\A[[:space:]]+|[[:space:]]+\z/, "")
  end

  def failure(message)
    Result.new(row: nil, error: message)
  end
end
