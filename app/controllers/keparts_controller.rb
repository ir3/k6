# frozen_string_literal: true

class KepartsController < ApplicationController
  before_action :set_kepart, only: %i[show edit update destroy]

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
  # GET /keparts/1.json
  def show
    @kepart = Kepart.find(params[:id])
    @num = 0
    @stockbs = Stockb.where(partno: @kepart.pcode)
    @stockbs.each do |stock|
      @num += stock.num
    end
    @stockb = Stockb.new
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
  def destroy
    @kepart.destroy
    respond_to do |format|
      format.html { redirect_to keparts_url, notice: 'Kepart was successfully destroyed.' }
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
