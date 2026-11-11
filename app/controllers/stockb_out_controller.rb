# frozen_string_literal: true

# Ｂ部品出庫入力（旧 zaikoout2.asp → syukoEntry2.asp）。Ａ部品の出庫入力と同じ画面で、台帳が在庫台帳B、部品がKE部品。
# Ｂ部品在庫メンテナンスの「出庫登録」から開く。
class StockbOutController < StockOutController
  private

  def build_maintainer = StockbMaintainer.new(params[:partno])

  def entry_path = stockb_out_path

  def maintenance_path_for(partno) = stockb_maintenance_path(partno: partno)

  def entry_title = "Ｂ部品出庫入力"
end
