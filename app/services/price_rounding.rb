# frozen_string_literal: true

# 掛け率を掛けた単価の丸め（asp/include/fsysfunc.asp の kmarume / smarume 相当）。
# 金額の大きさに応じて、1万円未満は1円の桁、10万円未満は10円の桁、100万円未満は100円の桁、
# 100万円以上は1000円の桁までを常に 0 にそろえる（丸める単位は 10 / 100 / 1000 / 10000 円）。
module PriceRounding
  module_function

  # 丸める単位（1万円未満は10円、10万円未満は100円、100万円未満は1000円、それ以上は1万円）
  def unit_for(price)
    if price < 10_000 then 10
    elsif price < 100_000 then 100
    elsif price < 1_000_000 then 1_000
    else 10_000
    end
  end

  # 切り上げ（kmarume）。ASPと同じく、まず小数点以下を切り捨ててから単位に切り上げる
  def round_up(price)
    whole = price.floor
    unit = unit_for(whole)
    (whole % unit).zero? ? whole : ((whole / unit) + 1) * unit
  end

  # 四捨五入（smarume）。ASPの VBScript では、整数に丸めた値が単位で割り切れると
  # 四捨五入せず切り捨てになる癖があった(1009.6 → 1009)が、1円の桁を常に 0 にする
  # 本来の意図に合わせて、単位への四捨五入にそろえている。
  def round_half_up(price)
    unit = unit_for(price)
    ((price.to_f / unit) + 0.5).floor * unit
  end
end
