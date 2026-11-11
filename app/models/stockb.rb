# frozen_string_literal: true

# 在庫台帳B（Ｂ部品）。入庫は num が正、出庫は負（Stock と同じ）。
class Stockb < ActiveRecord::Base
  include StockLedger
end
