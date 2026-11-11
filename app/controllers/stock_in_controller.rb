# frozen_string_literal: true

# 入庫入力（旧 zaikoin.asp）。部品の入庫を、入庫数・仕入時販売単価・入庫区分・備考・船名・会社名で登録する。
# 在庫メンテナンスの「入庫入力」から開く。部品番号が無いときは、旧ASPと同じく部品番号の入力欄を出す。
class StockInController < ApplicationController
  before_action :set_maintainer
  before_action :require_known_part, only: :create

  # GET /stock_in?partno=...
  def new
    return render :select if @maintainer.partno.empty?
    return redirect_to(stock_in_path, alert: unknown_message) unless @maintainer.known?

    @form = { price: @maintainer.part&.newprice, ikubun: 1 }
    load_screen
  end

  # POST /stock_in
  def create
    @form = form_params
    result = @maintainer.receive(**@form.slice(:num, :price, :ikubun, :memo, :ship, :company))
    if result.success?
      redirect_to stock_maintenance_path(partno: @maintainer.partno), status: :see_other, notice: result.message
    else
      flash.now[:alert] = result.error
      load_screen
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_maintainer
    @maintainer = StockMaintainer.new(params[:partno])
  end

  def require_known_part
    return redirect_to(stock_in_path, alert: "部品番号が指定されていません。") if @maintainer.partno.empty?

    redirect_to(stock_in_path, alert: unknown_message) unless @maintainer.known?
  end

  def unknown_message
    "部品「#{@maintainer.partno}」は部品台帳にも在庫台帳にも見つかりません。"
  end

  # 画面に出す、部品の情報と現在の在庫数
  def load_screen
    @part = @maintainer.part
    @on_hand = Stock.on_hand(@maintainer.partno)
  end

  # 入力欄の値（入力し直せるように、エラーのときは画面に戻す）
  def form_params
    params.permit(:num, :price, :ikubun, :memo, :ship, :company).to_h.symbolize_keys.reverse_merge(
      num: nil, price: nil, ikubun: nil, memo: nil, ship: nil, company: nil
    )
  end
end
