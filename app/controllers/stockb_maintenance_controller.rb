# frozen_string_literal: true

# Ｂ部品在庫メンテナンス（旧 hzaikomente.asp）。部品ごとに、在庫数と入出荷の履歴を見て、
# 実在庫との一致化・表示/非表示の設定をする。入庫・出庫の登録は、ここのボタンから別の画面を開く。
# Ａ部品の在庫メンテナンスと同じ動きで、台帳が在庫台帳B、部品がKE部品。標準在庫数・予測量・単価更新は、旧ASPのＢ部品の画面に無い。
# Ｂ部品在庫表示（/stockbs）の行から開く。
class StockbMaintenanceController < StockMaintenanceController
  # GET /stockb_maintenance?partno=...&all=1
  def show
    @part = @maintainer.part
    @history = StockbHistory.new(@maintainer.partno, all: params[:all].present?)
    if @part.nil? && @history.total.zero?
      return redirect_back_or_to(menu_path, alert: @maintainer.unknown_message)
    end

    @setting = StockbSetting.for_part(@maintainer.partno)
    # 旧部品コードと補足情報は、旧ASPがＡ部品と同じ表（在庫部品備考）から読むので、Ａ部品の在庫の設定から読む
    @notes = StockSetting.for_part(@maintainer.partno)
    @on_hand = @maintainer.on_hand
  end

  private

  def build_maintainer = StockbMaintainer.new(params[:partno])

  def maintenance_path_for(partno) = stockb_maintenance_path(partno: partno)
end
