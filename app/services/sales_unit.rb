# frozen_string_literal: true

# 部品の販売単位の表記。部品台帳の販売単位(Part#sel_unit)は、数字(例: 10 = 10個で1袋)か
# SET・ｸﾐ・PCSなどの文字で入っている。見積書・請求書・納品書は、旧ASPと同じく
# 上段に販売単位そのもの、下段に単位の名前(数字のとき「袋」)を出す。
module SalesUnit
  NUMERIC = /\A\d+(\.\d+)?\z/

  # 販売単位が数字か(例: "10")
  def self.numeric?(unit)
    unit.to_s.strip.match?(NUMERIC)
  end

  # 上段に出す販売単位(空ならnil)
  def self.sel_unit(unit)
    unit.to_s.strip.presence
  end

  # 下段に出す単位の名前。数字のときだけ「袋」、文字のときは上段に出ているので出さない
  def self.name(unit)
    numeric?(unit) ? "袋" : nil
  end
end
