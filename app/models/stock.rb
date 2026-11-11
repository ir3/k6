# frozen_string_literal: true

# 在庫台帳（Ａ部品）。入庫は num が正、出庫は負。
class Stock < ActiveRecord::Base
  include StockLedger
end
