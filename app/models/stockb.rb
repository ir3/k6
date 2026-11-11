# frozen_string_literal: true

# 在庫台帳B。入庫は num が正、出庫は負（Stock と同じ）。
class Stockb < ActiveRecord::Base
  # 数量の集計に入れる行（削除済みと無効(novalid=1)を除く）
  scope :counted, -> { where(deleted_at: nil).where("novalid IS NULL OR novalid = 0") }
end
