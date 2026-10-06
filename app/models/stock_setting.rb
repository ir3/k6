# frozen_string_literal: true

# 部品ごとの在庫の設定（標準在庫数・予測量・旧部品コード・補足情報・非表示）。在庫メンテナンス画面で使う。
class StockSetting < ActiveRecord::Base
  # 部品番号は大文字にそろえて探す（在庫台帳には小文字のものもある）
  def self.for_part(partno)
    find_or_initialize_by(partno: partno.to_s.strip.upcase)
  end

  def hidden?
    nonview.to_i == 1
  end
end
