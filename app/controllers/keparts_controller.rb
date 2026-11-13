# frozen_string_literal: true

class KepartsController < ApplicationController
  before_action :set_kepart, only: %i[show edit update update_field destroy]

  # GET /keparts
  # GET /keparts.json
  # Ｂ部品台帳表示（旧 hiteijosel.asp）。部品コードの一部で検索する。
  # 旧ASPと同じく、検索した部品コードに「~」が含まれるときは「~」付きのＢ部品だけ（列は寸法）、
  # 含まれないとき（検索なしの初期表示も）は「~」の無いＢ部品だけ（列は形式）を出す。
  def index
    @keyword = params[:keyword].to_s.unicode_normalize(:nfkc).strip
    @tilde = @keyword.include?("~")
    scope = Kepart.where("pcode LIKE ?", "%#{Kepart.sanitize_sql_like(@keyword)}%")
    scope = @tilde ? scope.where("pcode LIKE '%~%'") : scope.where("pcode NOT LIKE '%~%'")
    @keparts = scope.order(:id).page params[:page]
  end

  # POST /keparts/search
  def search
    @keyword = params[:keyword]
    logger.debug @keyword
    @keparts = Kepart.where("pcode LIKE ?", "%#{Kepart.sanitize_sql_like(@keyword)}%").page params[:page]

    render :index
  end

  # GET /keparts/1
  # Ｂ部品メンテナンス（旧 hiteijomente.asp）。KE部品の定義を見て、項目ごとに登録し直す。
  # Ｂ部品在庫メンテナンスの「部品定義参照」、KE部品の一覧、注文部品の部品コードから開く。
  def show
    @stockb_rows = Stockb.where(partno: @kepart.pcode).count
  end

  # PATCH /keparts/1/field（1回に1項目。旧 kepartsedits / kepartseditt / kepricereg / hnpartsb 相当）
  def update_field
    result = KepartEditor.new(@kepart, params[:field], params[:value]).call
    flash_key = result.success? ? :notice : :alert
    redirect_to kepart_path(@kepart), status: :see_other,
                flash_key => result.success? ? "#{result.label}を登録しました。" : result.error
  end

  # GET /keparts/new?nparts=部品コード
  # 新規Ｂ部品登録（旧 hnpartsreg.asp → npartsr3.asp）。Ｂ部品台帳表示の「新規Ｂ部品登録」の枠から開く。
  # - Ａ部品に、その部品コードがある: Ａ部品の名称・単価・重量を引き継いだ登録画面（部品コードは末尾に「~」）
  # - Ｂ部品台帳に、すでにある: 登録できないので、在庫を登録するＢ部品在庫メンテナンスへ案内する
  # - どちらにも無い: Ｂ部品詳細入力（旧 npartsr32.asp）の登録画面
  def new
    # 注文部品詳細の「部品番号を入力して部品選択」から来たときは、登録のあと、その注文に戻って明細に追加する
    @order = Order.find_by(id: params[:order_id]) if params[:order_id].present?
    code = PartCode.normalize(params[:nparts])
    return redirect_to(keparts_path, alert: "新規登録する部品コードを入力してください。") if code.empty?

    part = Part.where("UPPER(pcode) = ?", code).first
    existing = Kepart.where("UPPER(pcode) = ?", code).first
    if part
      @source = :part
      @values = KepartRegistrar.defaults_from(part)
    elsif existing
      redirect_to stockb_maintenance_path(partno: existing.pcode),
                  notice: "Ｂ部品「#{existing.pcode}」は、すでにＢ部品台帳にあります。在庫は、このＢ部品在庫メンテナンスで登録してください。"
    else
      @source = :scratch
      @values = { pcode: code, munit: "1", num: "1" }
    end
  end

  # GET /keparts/1/edit
  def edit; end

  # POST /keparts
  # POST /keparts.json
  # 旧 hpartsreg6.asp / partsreg44.asp と同じく、KE部品台帳と在庫台帳Ｂに1行ずつ登録する。
  # 登録のあとは、その部品コードで絞り込んだ一覧（旧 hiteijosel.asp）へ戻る
  def create
    source = params[:source].to_s == "scratch" ? :scratch : :part
    @order = Order.find_by(id: params[:order_id]) if params[:order_id].present?
    result = KepartRegistrar.new(kepart_input, source: source, order: @order).call

    respond_to do |format|
      if result.success? && @order
        # 注文から来たときは、KE部品台帳と注文の明細に足して（在庫台帳Ｂには足さない。旧 partsreg4.asp）、注文に戻る
        format.html do
          redirect_to order_path(@order), status: :see_other,
                                          notice: "Ｂ部品「#{result.kepart.pcode}」を登録し、この注文の明細に追加しました（数量 #{result.orderpart.qty}・単価 #{result.orderpart.unitpd}）。"
        end
        format.json { render json: result.kepart, status: :created, location: result.kepart }
      elsif result.success?
        format.html do
          redirect_to keparts_path(keyword: result.kepart.pcode), status: :see_other,
                                                                  notice: "Ｂ部品「#{result.kepart.pcode}」と、在庫台帳Ｂの1行を登録しました。"
        end
        format.json { render json: result.kepart, status: :created, location: result.kepart }
      else
        # 入力したままの値で、登録画面に戻る（Turbo は 422 でないと、画面を差し替えない）
        @source = source
        @values = kepart_input.to_h.symbolize_keys
        @error = result.error
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { error: result.error }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /keparts/1
  # PATCH/PUT /keparts/1.json
  def update
    respond_to do |format|
      if @kepart.update(kepart_params)
        format.html { redirect_to @kepart, notice: "Kepart was successfully updated." }
        format.json { render :show, status: :ok, location: @kepart }
      else
        format.html { render :edit }
        format.json { render json: @kepart.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /keparts/1
  # DELETE /keparts/1.json
  # 旧 kepartsdel.asp と同じく、KE部品の行を消す（在庫台帳Bの履歴は消さない）。
  # 削除のあとの転送は 303（Turbo の DELETE は、303 でないと、削除後の画面に DELETE を送り直す）
  def destroy
    code = @kepart.pcode
    @kepart.destroy
    respond_to do |format|
      format.html { redirect_to keparts_url, status: :see_other, notice: "Ｂ部品「#{code}」を削除しました。" }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_kepart
    @kepart = Kepart.find(params[:id])
  end

  # 登録画面から来る項目だけを受け付ける
  def kepart_input
    params.fetch(:kepart, {}).permit(:pcode, :size, :jname, :ename, :munit, :num, :weightkg, :newprice, :itemno, :ikubun)
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def kepart_params
    params.require(:kepart).permit(:pcode, :form, :size, :jname, :ename, :newprice, :price, :stock, :sel_unit, :weightkg, :munit, :itemno, :cordno, :comment, :created_at, :updated_at, :deleted_at)
  end
end
