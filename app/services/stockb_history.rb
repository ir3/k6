# frozen_string_literal: true

# Ｂ部品在庫メンテナンス画面の「この部品の入出荷状況」。Ａ部品の StockHistory の在庫台帳B版。
# 旧 hzaikomente.asp は、履歴の日付に、台帳の入庫日付や出庫日付ではなく更新日(Updata)の日付を出す。
class StockbHistory < StockHistory
  private

  def ledger = Stockb

  def row_date(stock)
    stock.updated_at.to_date
  end
end
