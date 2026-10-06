# frozen_string_literal: true

# 部品番号を入力して、注文に部品明細を追加する（asp/partsreg3.asp 相当）。
#
# 入力された部品番号で部品台帳(Part)を探し、見つかれば注文の部品明細(Orderpart)に1行追加する。
# 在庫台帳(Stock)にも登録がある部品は、partsreg3.asp と同じく「^」付きの在庫行を先に1行追加し、
# 続けて通常の行も1行追加する（合計2行）。実データでは同じ部品に両方ある注文は少ないが、
# 業務上の指定で ASP のコードどおりにしている。在庫行を足したくない場合は call の
# `create_row(part, kzaiko: STOCK_MARK) if in_stock_ledger?(partno)` を外す。
class OrderPartAdder
  # 部品台帳に ItemNo / CORDNo が無い時の既定値（partsreg3.asp と同じ）
  DEFAULT_ITEMNO = "1"
  DEFAULT_CORDNO = "2"
  # 在庫台帳から出す部品に付ける印
  STOCK_MARK = "^"

  Result = Data.define(:rows, :partno, :error, :warnings) do
    def success? = error.nil?
  end

  # 部品台帳(Part/Kepart)の重量(kg)を計測単位で割った1個あたりの重量。小数3桁、負や未設定は0。
  # 数量を変えたときの重量の再計算(OrderpartEditor)でも使う。
  def self.unit_weight(part)
    weight = part.weightkg.to_f
    weight /= part.munit if part.munit.to_i.positive?
    weight.round(3).positive? ? weight.round(3) : 0.0
  end

  def initialize(order, input)
    @order = order
    @input = input
  end

  def call
    return failure("管理番号がない注文には部品を追加できません。") if @order.mno.blank?

    partno = normalize(@input)
    return failure("部品番号を入力してください。") if partno.empty?

    part = Part.where("UPPER(pcode) = ?", partno).first
    return failure("部品番号「#{partno}」は部品台帳に見つかりません。") unless part

    rows = []
    Orderpart.transaction do
      rows << create_row(part, kzaiko: STOCK_MARK) if in_stock_ledger?(partno)
      rows << create_row(part)
    end
    Result.new(rows: rows, partno: part.pcode, error: nil, warnings: warnings_for(part))
  end

  private

  # 全角→半角にそろえ、前後の空白を除いて大文字にする（partsreg3.asp の UCase 相当）
  def normalize(input)
    input.to_s.unicode_normalize(:nfkc).strip.upcase
  end

  def failure(message)
    Result.new(rows: [], partno: nil, error: message, warnings: [])
  end

  # 在庫台帳に登録がある部品か（在庫数は問わない。partsreg3.asp は部品番号で検索するだけ）
  def in_stock_ledger?(partno)
    Stock.where(deleted_at: nil).where("UPPER(partno) = ?", partno).exists?
  end

  # 単価は新販売単価、数量は1、掛け率は注文のA部品掛け率（未設定なら等倍）
  def create_row(part, kzaiko: nil)
    price = part.newprice.to_i
    weight = self.class.unit_weight(part)
    Orderpart.create!(
      mno: @order.mno, sno: @order.next_part_sno, partno: part.pcode, kzaiko: kzaiko,
      itemno: part.itemno.presence || DEFAULT_ITEMNO, cordno: part.cordno.presence || DEFAULT_CORDNO,
      qty: 1, unitpd: price, irate: @order.irate || 1.0, totala: price,
      unitweight: weight, totalweight: weight
    )
  end

  def warnings_for(part)
    part.newprice.to_i.zero? ? [ "新販売単価が未設定のため、単価0で追加しました。" ] : []
  end
end
