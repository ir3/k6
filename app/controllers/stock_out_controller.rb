# frozen_string_literal: true

# 出庫入力（旧 zaikoout.asp）。部品の出庫を、出庫数・仕入時販売単価・取引管理No・出庫区分・備考・船名・会社名で登録する。
# 在庫メンテナンスの「出庫登録」から開く。取引管理No が渡されたとき(?mno=)は、出荷先の船名・会社名を取引台帳から入れる。
# 出庫数が渡されたとき(?num=)は、出庫数の初期値にする。
# Ｂ部品は StockbOutController（旧 zaikoout2.asp / syukoEntry2.asp）が、行き先と台帳だけ入れ替えて使う。
class StockOutController < ApplicationController
  before_action :set_maintainer
  before_action :require_known_part, only: :create
  helper_method :entry_path, :maintenance_path_for, :entry_title

  # GET /stock_out?partno=...&mno=...
  def new
    return render :select if @maintainer.partno.empty?
    return redirect_to(entry_path, alert: @maintainer.unknown_message) unless @maintainer.known?

    # ?num= は、出庫数の初期値（注文部品詳細の「この部品を在庫から引き当て、在庫数を減算する」が、その明細の数量を渡す）。
    # 出庫数として受け付けられない値（0・負・数でない値・大きすぎる値）は、空白のままにする
    @form = { price: @maintainer.part&.newprice, okubun: 2, mno: params[:mno].to_s.strip.presence,
              num: IntegerInput.parse(params[:num], StockMaintainer::ISSUE_RANGE) }
    destination = StockMaintainer.destination(@form[:mno])
    @form.merge!(ship: destination[:ship], company: destination[:company]) if destination
    load_screen
  end

  # POST /stock_out
  def create
    @form = form_params
    result = @maintainer.issue(**@form.slice(:num, :price, :okubun, :mno, :memo, :ship, :company))
    if result.success?
      redirect_to maintenance_path_for(@maintainer.partno), status: :see_other, notice: result.message
    else
      flash.now[:alert] = result.error
      load_screen
      render :new, status: :unprocessable_entity
    end
  end

  private

  # --- Ｂ部品（StockbOutController）が入れ替えるところ ---

  def build_maintainer = StockMaintainer.new(params[:partno])

  # この画面（フォームの送り先・やり直しの行き先）
  def entry_path = stock_out_path

  # 登録のあとに戻る在庫メンテナンス
  def maintenance_path_for(partno) = stock_maintenance_path(partno: partno)

  def entry_title = "出庫入力"

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
    params.permit(:num, :price, :okubun, :mno, :memo, :ship, :company).to_h.symbolize_keys.reverse_merge(
      num: nil, price: nil, okubun: nil, mno: nil, memo: nil, ship: nil, company: nil
    )
  end
end
