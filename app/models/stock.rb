# frozen_string_literal: true

# 在庫台帳。入庫は num が正、出庫は負。
class Stock < ActiveRecord::Base
  # 入庫区分・出庫区分（旧Accessの 入庫区分 / 出庫区分 テーブル）
  INBOUND_KINDS = { 1 => "買取品", 2 => "返品(貸出分)", 3 => "返品(キャンセル)", 4 => "返品(誤送品)" }.freeze
  OUTBOUND_KINDS = { 1 => "貸出分", 2 => "売掛分" }.freeze

  # 部品番号(大文字小文字を区別しない)の台帳の行
  scope :of_part, ->(partno) { where("UPPER(partno) = ?", partno.to_s.strip.upcase) }
  # 数量の集計に入れる行（削除済みと無効(novalid=1)を除く）
  scope :counted, -> { where(deleted_at: nil).where("novalid IS NULL OR novalid = 0") }

  # 現在の在庫数（計算在庫数）。入庫と出庫の数量の合計
  def self.on_hand(partno)
    of_part(partno).counted.sum(:num)
  end

  # 備考の先頭に付ける区分名。区分が無い・0 のものは名前が無い
  def kind_labels
    [ INBOUND_KINDS[ikubun], OUTBOUND_KINDS[okubun] ].compact
  end
end
