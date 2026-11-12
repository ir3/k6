# frozen_string_literal: true

class PartsController < ApplicationController
  before_action :require_authentication
  before_action :set_part, only: %i[show update_field duplicate destroy]

  # GET /parts
  # GET /parts.json
  # Ａ部品台帳表示（旧 partssel.asp）。部品コードの一部で検索する。
  # 入れた値が在庫設定の旧部品番号と一致したら、対応する新しい部品も出す。
  def index
    @keyword = params[:keyword].to_s.unicode_normalize(:nfkc).strip
    if @keyword.empty?
      @parts = Part.order("id").page params[:page]
    else
      new_codes = StockSetting.where("UPPER(opartno) = ?", @keyword.upcase).pluck(:partno)
      @old_number_found = new_codes.any?
      @parts = Part.where("pcode LIKE ? OR pcode IN (?)", "%#{Part.sanitize_sql_like(@keyword)}%", new_codes)
                   .order(:id).page params[:page]
    end

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @parts }
    end
  end

  # GET /parts/1
  # GET /parts/1.json
  # Ａ部品メンテナンス（旧 partsmente.asp）。部品台帳の定義を見て、項目ごとに登録し直す。
  # Ａ部品台帳表示の部品コード、注文明細・並べ替え画面の部品コードから開く。在庫は「部品在庫参照」から見る。
  def show
    @stock_rows = Stock.where("UPPER(partno) = ?", @part.pcode.to_s.upcase).count
    @old_part_number = StockSetting.find_by(partno: @part.pcode.to_s.strip.upcase)&.opartno

    respond_to do |format|
      format.html
      format.json { render json: @part }
    end
  end

  # PATCH /parts/1/field（1回に1項目。旧 npartsedit* 相当）
  def update_field
    result = PartEditor.new(@part, params[:field], params[:value]).call
    flash_key = result.success? ? :notice : :alert
    redirect_to part_path(@part), status: :see_other,
                flash_key => result.success? ? "#{result.label}を登録しました。" : result.error
  end

  # POST /parts/1/duplicate（旧 npartsreg2 相当。新しい部品コードで、元の情報を保持した部品を作る）
  def duplicate
    result = PartDuplicator.new(@part, params[:new_code]).call
    if result.success?
      redirect_to part_path(result.part), status: :see_other, notice: "新しい部品「#{result.part.pcode}」を作りました。"
    else
      redirect_to part_path(@part), status: :see_other, alert: result.error
    end
  end

  # GET /parts/new
  # GET /parts/new.json
  # Ａ部品詳細入力（旧 npartsr.asp）。Ａ部品台帳表示の「新規Ａ部品登録」から、?nparts= で部品コードを受け取る。
  def new
    # 入力欄の初期値（数値欄の入力を、失敗のあと文字列のまま画面に戻すため、モデルではなく値で持つ）
    @values = { pcode: PartCode.normalize(params[:nparts]), munit: "1" }

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: Part.new(@values) }
    end
  end

  # GET /parts/1/edit
  def edit
    @part = Part.find(params[:id])
  end

  # POST /parts
  # POST /parts.json
  # 旧 partsreg7.asp と同じく、Ａ部品台帳に登録したあと、その部品コードで絞り込んだ一覧（旧 partssel.asp）へ戻る
  def create
    result = PartRegistrar.new(part_input).call

    respond_to do |format|
      if result.success?
        format.html do
          redirect_to parts_path(keyword: result.part.pcode), status: :see_other,
                                                              notice: "Ａ部品「#{result.part.pcode}」を登録しました。"
        end
        format.json { render json: result.part, status: :created, location: result.part }
      else
        # 入力したままの値で、入力画面に戻る（Turbo は 422 でないと、画面を差し替えない）
        @values = part_input.to_h.symbolize_keys
        @error = result.error
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { error: result.error }, status: :unprocessable_entity }
      end
    end
  end

  # PUT /parts/1
  # PUT /parts/1.json
  def update
    @part = Part.find(params[:id])

    respond_to do |format|
      #      if @part.update_attributes(params[:part])
      if @part.update(part_params)
        format.html { redirect_to @part, notice: "Part was successfully updated." }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @part.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /parts/1
  # DELETE /parts/1.json
  # 旧 partsdelA.asp と同じく、部品台帳の行を消す（在庫台帳の履歴は消さない）。
  # 削除のあとの転送は 303（Turbo の DELETE は、303 でないと、削除後の画面に DELETE を送り直す）
  def destroy
    code = @part.pcode
    @part.destroy

    respond_to do |format|
      format.html { redirect_to parts_url, status: :see_other, notice: "Ａ部品「#{code}」を削除しました。" }
      format.json { head :no_content }
    end
  end

  private

  def set_part
    @part = Part.find(params[:id])
  end

  # 登録画面から来る項目だけを受け付ける
  def part_input
    params.fetch(:part, {}).permit(:pcode, :form, :jname, :ename, :munit, :weightkg, :newprice)
  end
end
