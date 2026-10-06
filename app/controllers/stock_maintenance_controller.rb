# frozen_string_literal: true

# 在庫メンテナンス（旧 zaikomente.asp）。部品ごとに、在庫数・標準在庫数・予測量・入出荷の履歴を見て、
# 単価・表示/非表示・実在庫との一致化・標準在庫数・予測量を更新する。
# 注文部品詳細編集の「この部品の在庫状況」から開く。
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
    @maintainer = StockMaintainer.new(params[:partno])
    return unless @maintainer.partno.empty?

    redirect_to menu_path, alert: "部品番号が指定されていません。"
  end

  # 更新の結果を知らせて、在庫メンテナンスに戻る（POSTのリダイレクトは 303）
  def apply
    result = yield
    flash_key = result.success? ? :notice : :alert
    redirect_to stock_maintenance_path(partno: @maintainer.partno), status: :see_other,
                flash_key => result.success? ? result.message : result.error
  end
end
