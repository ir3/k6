# frozen_string_literal: true

# 在庫メンテナンス（旧 zaikomente.asp）。部品ごとに、在庫数・標準在庫数・予測量・入出荷の履歴を見て、
# 単価・表示/非表示・実在庫との一致化・標準在庫数・予測量を更新する。
# 注文部品詳細編集の「この部品の在庫状況」から開く。
# Ｂ部品は StockbMaintenanceController（旧 hzaikomente.asp）が、台帳と画面だけ入れ替えて使う。
class StockMaintenanceController < ApplicationController
  before_action :set_maintainer

  # GET /stock_maintenance?partno=...&all=1
  def show
    @part = @maintainer.part
    @history = StockHistory.new(@maintainer.partno, all: params[:all].present?)
    if @part.nil? && @history.total.zero?
      return redirect_back_or_to(menu_path, alert: "部品「#{@maintainer.partno}」は部品台帳にも在庫台帳にも見つかりません。")
    end

    @setting = StockSetting.for_part(@maintainer.partno)
    @on_hand = Stock.on_hand(@maintainer.partno)
  end

  # POST /stock_maintenance/price
  def price
    apply { @maintainer.change_price(params[:price]) }
  end

  # POST /stock_maintenance/hide (非表示設定) / POST /stock_maintenance/reveal (表示設定)
  def hide
    apply { @maintainer.set_hidden(true) }
  end

  def reveal
    apply { @maintainer.set_hidden(false) }
  end

  # POST /stock_maintenance/adjust
  def adjust
    apply { @maintainer.adjust_to(params[:zaikonum]) }
  end

  # POST /stock_maintenance/standard
  def standard
    apply { @maintainer.change_standard(params[:snum]) }
  end

  # POST /stock_maintenance/forecast
  def forecast
    apply { @maintainer.change_forecast(params[:znum]) }
  end

  private

  def set_maintainer
    @maintainer = build_maintainer
    return unless @maintainer.partno.empty?

    redirect_to menu_path, alert: "部品番号が指定されていません。"
  end

  # 更新の結果を知らせて、在庫メンテナンスに戻る（POSTのリダイレクトは 303）
  def apply
    result = yield
    flash_key = result.success? ? :notice : :alert
    redirect_to maintenance_path_for(@maintainer.partno), status: :see_other,
                flash_key => result.success? ? result.message : result.error
  end

  # --- Ｂ部品（StockbMaintenanceController）が入れ替えるところ ---

  def build_maintainer = StockMaintainer.new(params[:partno])

  # 更新のあとに戻る在庫メンテナンス
  def maintenance_path_for(partno) = stock_maintenance_path(partno: partno)
end
