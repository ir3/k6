# frozen_string_literal: true

# Ｂ部品の在庫メンテナンス（旧 hzaikomente.asp）からの更新。入庫・出庫の登録、実在庫に一致化、表示/非表示の設定。
# Ａ部品の StockMaintainer と同じ動きで、台帳（在庫台帳B）と部品台帳（KE部品台帳）、日付の入れ方が違うところだけ入れ替える。
#
# 実データ（在庫台帳B 70,000 行あまり）と旧ASP（nyukoEntry2.asp / syukoEntry2.asp）から分かっていること:
# - 入庫の行は kind=1 で、入庫日付と取引管理No は入れない（Ａ部品は kind=0 で入庫日付が入る）
# - 出庫の行は Ａ部品と同じ（kind=0、入庫日付に今日の日付）
# - 在庫台帳B には発注中(onum)が入っている行が1行も無い。なので入庫で発注中は減らさない
#   （旧 nyukoEntry2.asp はＡ部品の発注記録 v発注記録 を見ており、Ｂ部品の発注中ではない）
# - 実在庫への一致化の「調整」行も、正の差は入庫の行、負の差は出庫の行と同じ形
class StockbMaintainer < StockMaintainer
  def master_name = "KE部品台帳"

  def ledger_name = "在庫台帳B"

  private

  def ledger = Stockb

  def master = Kepart

  def setting_class = StockbSetting

  def incoming_defaults = { kind: 1, indate: nil }

  def reduces_order? = false
end
