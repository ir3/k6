# frozen_string_literal: true

class PartsController < ApplicationController
  before_action :require_authentication
  before_action :set_part, only: %i[show update_field duplicate destroy]

  # GET /parts
  # GET /parts.json
  def index
    @keyword = params[:keyword]
    @parts = if @keyword && !@keyword.empty?
               Part.where("pcode LIKE ?", "%#{Part.sanitize_sql_like(@keyword)}%").order(:id).page params[:page]
             else
               Part.order('id').page params[:page]
             end

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @parts }
    end
  end

  # POST /parts/search
  def search
    session[:user_id]
    keyword = params[:keyword]
    logger.debug keyword
    @parts = Part.find_by_sql("SELECT * FROM parts WHERE pcode like '#{keyword}%'")

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render xml: @parts }
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
  def new
    @part = Part.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @part }
    end
  end

  # GET /parts/1/edit
  def edit
    @part = Part.find(params[:id])
  end

  # POST /parts
  # POST /parts.json
  def create
    @part = Part.new(params[:part])

    respond_to do |format|
      if @part.save
        format.html { redirect_to @part, notice: 'Part was successfully created.' }
        format.json { render json: @part, status: :created, location: @part }
      else
        format.html { render action: 'new' }
        format.json { render json: @part.errors, status: :unprocessable_entity }
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
        format.html { redirect_to @part, notice: 'Part was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
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
end
