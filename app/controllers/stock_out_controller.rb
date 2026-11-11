# frozen_string_literal: true

# 出庫入力（旧 zaikoout.asp）。部品の出庫を、出庫数・仕入時販売単価・取引管理No・出庫区分・備考・船名・会社名で登録する。
# 在庫メンテナンスの「出庫登録」から開く。取引管理No が渡されたとき(?mno=)は、出荷先の船名・会社名を取引台帳から入れる。
class StockOutController < ApplicationController
  before_action :set_maintainer
  before_action :require_known_part, only: :create

  # GET /stock_out?partno=...&mno=...
  def new
    return render :select if @maintainer.partno.empty?
    return redirect_to(stock_out_path, alert: unknown_message) unless @maintainer.known?

    @form = { price: @maintainer.part&.newprice, okubun: 2, mno: params[:mno].to_s.strip.presence }
    destination = StockMaintainer.destination(@form[:mno])
    @form.merge!(ship: destination[:ship], company: destination[:company]) if destination
    load_screen
  end

  # POST /stock_out
  def create
    @form = form_params
    result = @maintainer.issue(**@form.slice(:num, :price, :okubun, :mno, :memo, :ship, :company))
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
    return redirect_to(stock_out_path, alert: "部品番号が指定されていません。") if @maintainer.partno.empty?

    redirect_to(stock_out_path, alert: unknown_message) unless @maintainer.known?
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
    params.permit(:num, :price, :okubun, :mno, :memo, :ship, :company).to_h.symbolize_keys.reverse_merge(
      num: nil, price: nil, okubun: nil, mno: nil, memo: nil, ship: nil, company: nil
    )
  end
end
