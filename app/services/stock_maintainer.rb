# frozen_string_literal: true

# 在庫メンテナンス画面からの更新（旧 zaikomente.asp の単価更新・表示/非表示設定・実在庫に一致化・
# 標準在庫数更新・予測数更新）。各更新用のASPは無いので、実データから振る舞いを推測している。
class StockMaintainer
  Result = Data.define(:message, :error) do
    def success? = error.nil?
  end

  PRICE_RANGE = 0..9_999_999
  QUANTITY_RANGE = 0..999_999
  RECEIVE_RANGE = 1..999_999
  SETTING_RANGE = 0..99_999
  ADJUST_MEMO = "調整"
  # 在庫台帳の備考・船名・会社名の長さ（旧Accessの列の長さ。Memo 255、Text(50)）
  MEMO_MAX = 255
  NAME_MAX = 50

  def initialize(partno)
    @partno = partno.to_s.unicode_normalize(:nfkc).strip.upcase
  end

  attr_reader :partno

  # 部品台帳の部品（無ければ nil）
  def part
    @part ||= Part.where("UPPER(pcode) = ?", @partno).first
  end

  # 部品台帳か在庫台帳のどちらかに登録がある部品か
  def known?
    !part.nil? || Stock.of_part(@partno).where(deleted_at: nil).exists?
  end

  # 入庫登録（旧 zaikoin.asp。登録処理の nyukoEntry.asp は無いので、実データの入庫行から振る舞いを推測している）。
  # 在庫台帳に入庫の行を1行足す。単価は在庫台帳の「入庫時の販売単価(irprice)」に記録するだけで、
  # 部品台帳の新販売単価は変えない（変えるのは「単価更新」）。
  # 発注中(onum)は、入庫した数だけ減らす。ただし発注中の残高より多くは減らさない（発注中がマイナスにならないように）。
  # 実データの入庫行 8,700 件あまりが、この規則（onum = -min(入庫数, 直前の発注中残高)）どおりに書かれている。
  def receive(num:, price:, ikubun:, memo: nil, ship: nil, company: nil)
    quantity = IntegerInput.parse(num, RECEIVE_RANGE)
    return failure("入庫数は #{RECEIVE_RANGE.begin} から #{RECEIVE_RANGE.end} の整数で入力してください。") unless quantity

    unit_price = IntegerInput.parse(price, PRICE_RANGE)
    return failure("仕入時販売単価は #{PRICE_RANGE.begin} から #{PRICE_RANGE.end} の整数で入力してください。") unless unit_price

    kind = IntegerInput.parse(ikubun, 1..4)
    return failure("入庫区分を選んでください。") unless Stock::INBOUND_KINDS.key?(kind)

    memo, ship, company = [ memo, ship, company ].map { |text| text.to_s.strip.presence }
    return failure("備考は #{MEMO_MAX} 文字以内で入力してください。") if memo && memo.length > MEMO_MAX
    return failure("船名は #{NAME_MAX} 文字以内で入力してください。") if ship && ship.length > NAME_MAX
    return failure("会社名は #{NAME_MAX} 文字以内で入力してください。") if company && company.length > NAME_MAX
    return failure("部品「#{@partno}」は部品台帳にも在庫台帳にも見つかりません。") unless known?

    reduced = 0
    Stock.transaction do
      onum = order_reduction(quantity)
      reduced = -onum
      Stock.create!(receipt_attributes(quantity, unit_price, kind, memo, ship, company, onum))
    end
    success(receive_message(quantity, kind, reduced))
  end

  # 単価更新。部品台帳の新販売単価を変える（注文に部品を追加するときの単価と同じ）
  def change_price(raw)
    return failure("部品台帳に登録がないので、単価は更新できません。") unless part

    price = IntegerInput.parse(raw, PRICE_RANGE)
    return failure("単価は #{PRICE_RANGE.begin} から #{PRICE_RANGE.end} の整数で入力してください。") unless price

    part.update!(newprice: price)
    success("単価を #{format_number(price)} 円に更新しました。")
  end

  # 実在庫に一致化。実在庫数と計算在庫数の差を「調整」行として在庫台帳に足す
  # （実データの調整行にならって、備考「調整」、取引No 0、差が正なら入庫区分1、負なら出庫区分2）
  def adjust_to(raw)
    actual = IntegerInput.parse(raw, QUANTITY_RANGE)
    return failure("実在庫数は #{QUANTITY_RANGE.begin} から #{QUANTITY_RANGE.end} の整数で入力してください。") unless actual

    on_hand = Stock.on_hand(@partno)
    diff = actual - on_hand
    return success("計算在庫数が #{on_hand} で実在庫数と同じなので、調整は登録しませんでした。") if diff.zero?

    Stock.create!(adjustment_attributes(diff))
    success("実在庫 #{actual} に一致化しました（計算在庫 #{on_hand} に対して #{format('%+d', diff)} の調整を登録）。")
  end

  def change_standard(raw)
    change_setting(:snum, raw, "標準在庫数")
  end

  def change_forecast(raw)
    change_setting(:znum, raw, "予測量")
  end

  # 非表示設定(hidden: true) / 表示設定(false)
  def set_hidden(hidden)
    setting = StockSetting.for_part(@partno)
    setting.update!(nonview: hidden ? 1 : nil)
    success(hidden ? "在庫を非表示に設定しました。" : "在庫を表示に設定しました。")
  end

  private

  def change_setting(column, raw, label)
    value = IntegerInput.parse(raw, SETTING_RANGE)
    return failure("#{label}は #{SETTING_RANGE.begin} から #{SETTING_RANGE.end} の整数で入力してください。") unless value

    StockSetting.for_part(@partno).update!(column => value)
    success("#{label}を #{value} に更新しました。")
  end

  def adjustment_attributes(diff)
    {
      partno: part&.pcode || @partno, kind: 0, indate: Date.current, num: diff, onum: 0,
      inprice: 0, irprice: adjustment_price, invalue: 0, irvalue: 0, orprice: 0, orvalue: 0,
      mno: 0, memo: ADJUST_MEMO, novalid: 0,
      ikubun: diff.positive? ? 1 : 0, okubun: diff.positive? ? 0 : 2
    }
  end

  # 入庫の行。実データの入庫行にならって、区分・日付・数量・単価・備考・船名・会社名のほかは 0（またはなし）にする
  def receipt_attributes(quantity, unit_price, kind, memo, ship, company, onum)
    {
      partno: part&.pcode || @partno, kind: 0, indate: Date.current, num: quantity, onum: onum,
      inprice: 0, irprice: unit_price, invalue: 0, irvalue: 0, orprice: 0, orvalue: 0,
      mno: 0, memo: memo, cname: company, sname: ship, novalid: 0, ikubun: kind, okubun: 0
    }
  end

  # 入庫の行に入れる onum。発注中の残高を超えない範囲で、入庫数ぶん減らす（マイナスの値）
  def order_reduction(quantity)
    on_order = Stock.of_part(@partno).counted.sum(:onum)
    on_order.positive? ? -[ quantity, on_order ].min : 0
  end

  def receive_message(quantity, kind, reduced)
    message = "#{part&.pcode || @partno} を #{quantity} 入庫登録しました（#{Stock::INBOUND_KINDS[kind]}。現在の在庫数 #{Stock.on_hand(@partno)}）。"
    reduced.positive? ? "#{message}発注中を #{reduced} 減らしました。" : message
  end

  # 調整行の単価は部品台帳の新販売単価。台帳に無い部品は在庫台帳の直近の単価
  def adjustment_price
    return part.newprice.to_i if part

    Stock.of_part(@partno).where.not(irprice: nil).reorder(id: :desc).pick(:irprice).to_i
  end

  def success(message) = Result.new(message: message, error: nil)

  def failure(message) = Result.new(message: nil, error: message)

  def format_number(value) = value.to_s.gsub(/(?<=\d)(?=(?:\d{3})+(?!\d))/, ",")
end
