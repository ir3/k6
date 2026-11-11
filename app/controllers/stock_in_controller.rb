# frozen_string_literal: true

# 入庫入力（旧 zaikoin.asp）。部品の入庫を、入庫数・仕入時販売単価・入庫区分・備考・船名・会社名で登録する。
# 在庫メンテナンスの「入庫登録」から開く。部品番号が無いときは、旧ASPと同じく部品番号の入力欄を出す。
# Ｂ部品は StockbInController（旧 zaikoin2.asp）が、行き先と台帳だけ入れ替えて使う。
class StockInController < ApplicationController
  before_action :set_maintainer
  before_action :require_known_part, only: :create
  helper_method :entry_path, :maintenance_path_for, :entry_title

  # GET /stock_in?partno=...
  def new
    return render :select if @maintainer.partno.empty?
    return redirect_to(entry_path, alert: @maintainer.unknown_message) unless @maintainer.known?

    @form = { price: @maintainer.part&.newprice, ikubun: 1 }
    load_screen
  end

  # POST /stock_in
  def create
    @form = form_params
    result = @maintainer.receive(**@form.slice(:num, :price, :ikubun, :memo, :ship, :company))
    if result.success?
      redirect_to maintenance_path_for(@maintainer.partno), status: :see_other, notice: result.message
    else
      flash.now[:alert] = result.error
      load_screen
      render :new, status: :unprocessable_entity
    end
  end

  private

  # --- Ｂ部品（StockbInController）が入れ替えるところ ---

  def build_maintainer = StockMaintainer.new(params[:partno])

  # この画面（フォームの送り先・やり直しの行き先）
  def entry_path = stock_in_path

  # 登録のあとに戻る在庫メンテナンス
  def maintenance_path_for(partno) = stock_maintenance_path(partno: partno)

  def entry_title = "入庫入力"

  # --- ここから共通 ---

  def set_maintainer
    @maintainer = build_maintainer
  end

  def require_known_part
    return redirect_to(entry_path, alert: "部品番号が指定されていません。") if @maintainer.partno.empty?

    redirect_to(entry_path, alert: @maintainer.unknown_message) unless @maintainer.known?
  end

  # 画面に出す、部品の情報と現在の在庫数
  def load_screen
    @part = @maintainer.part
    @on_hand = @maintainer.on_hand
  end

  # 入力欄の値（入力し直せるように、エラーのときは画面に戻す）
  def form_params
    params.permit(:num, :price, :ikubun, :memo, :ship, :company).to_h.symbolize_keys.reverse_merge(
      num: nil, price: nil, ikubun: nil, memo: nil, ship: nil, company: nil
    )
  end
end
