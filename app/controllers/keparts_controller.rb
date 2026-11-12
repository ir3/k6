# frozen_string_literal: true

class KepartsController < ApplicationController
  before_action :set_kepart, only: %i[show edit update update_field destroy]

  # GET /keparts
  # GET /keparts.json
  def index
    @keyword = params[:keyword]
    @keparts = if @keyword && !@keyword.empty?
                 Kepart.where("pcode LIKE ?", "%#{Kepart.sanitize_sql_like(@keyword)}%").order(:id).page params[:page]
               else
                 Kepart.page params[:page]
               end
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

  # GET /keparts/new
  def new
    @kepart = Kepart.new
  end

  # GET /keparts/1/edit
  def edit; end

  # POST /keparts
  # POST /keparts.json
  def create
    @kepart = Kepart.new(kepart_params)

    respond_to do |format|
      if @kepart.save
        format.html { redirect_to @kepart, notice: 'Kepart was successfully created.' }
        format.json { render :show, status: :created, location: @kepart }
      else
        format.html { render :new }
        format.json { render json: @kepart.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /keparts/1
  # PATCH/PUT /keparts/1.json
  def update
    respond_to do |format|
      if @kepart.update(kepart_params)
        format.html { redirect_to @kepart, notice: 'Kepart was successfully updated.' }
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

  # Never trust parameters from the scary internet, only allow the white list through.
  def kepart_params
    params.require(:kepart).permit(:pcode, :form, :size, :jname, :ename, :newprice, :price, :stock, :sel_unit, :weightkg, :munit, :itemno, :cordno, :comment, :created_at, :updated_at, :deleted_at)
  end
end
