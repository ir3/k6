# frozen_string_literal: true

# Ｂ部品ごとの在庫の設定（今は非表示だけ）。Ｂ部品在庫表示と在庫メンテナンスで使う。
# 旧Accessの 在庫非表示B に当たる（旧ASPは、行があれば非表示、行を消せば表示）。
# Ａ部品とＢ部品で同じ部品コードがあるので、Ａ部品の stock_settings とは別の表にしている。
class StockbSetting < ActiveRecord::Base
  # 部品番号は大文字にそろえて探す（在庫台帳には小文字のものもある）
  def self.for_part(partno)
    find_or_initialize_by(partno: partno.to_s.strip.upcase)
  end

  def hidden?
    nonview.to_i == 1
  end
end
