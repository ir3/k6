# frozen_string_literal: true

# Ｂ部品入庫入力（旧 zaikoin2.asp → nyukoEntry2.asp）。Ａ部品の入庫入力と同じ画面で、台帳が在庫台帳B、部品がKE部品。
# Ｂ部品在庫メンテナンスの「入庫登録」から開く。
class StockbInController < StockInController
  private

  def build_maintainer = StockbMaintainer.new(params[:partno])

  def entry_path = stockb_in_path

  def maintenance_path_for(partno) = stockb_maintenance_path(partno: partno)

  def entry_title = "Ｂ部品入庫入力"
end
