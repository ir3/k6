# frozen_string_literal: true

class StockbsController < ApplicationController
  before_action :set_stockb, only: %i[show edit update destroy]

  # GET /stockbs
  # Ｂ部品在庫表示。部品ごとに在庫の増減を集計した一覧（旧 hzaikolist.asp → hzaikosel.asp）。
  # partno: 部品コードの一部、in_stock: 在庫数が1以上の部品だけ
  def index
    @partno = params[:partno]
    @in_stock = params[:in_stock].present?

    list = StockbList.new(partno: @partno, in_stock: @in_stock)
    @second_title = list.second_title
    @rows = Kaminari.paginate_array(list.rows).page(params[:page])
  end

  # GET /stockbs/1
  # GET /stockbs/1.json
  def show; end

  # GET /stockbs/new
  def new
    @stockb = Stockb.new
  end

  # GET /stockbs/1/edit
  def edit; end

  # POST /stockbs
  # POST /stockbs.json
  def create
    @stockb = Stockb.new(stockb_params)

    # 出荷登録の場合は、入出庫数をマイナスにする
    @stockb.num = -1 * @stockb.num if @stockb.okubun

    respond_to do |format|
      if @stockb.save
        # B部品詳細表示更新へ
        id = Kepart.find_by(pcode: @stockb.partno).id
        format.html { redirect_to "/keparts/#{id}", notice: "\u5728\u5EAB\u3092\u66F4\u65B0\u3057\u307E\u3057\u305F" }
        #      format.html { redirect_to @stockb, notice: 'Stockb was successfully created.' }
        format.json { render :show, status: :created, location: @stockb }
      else
        format.html { render :new }
        format.json { render json: @stockb.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /stockbs/1
  # PATCH/PUT /stockbs/1.json
  def update
    respond_to do |format|
      if @stockb.update(stockb_params)
        format.html { redirect_to @stockb, notice: "Stockb was successfully updated." }
        format.json { render :show, status: :ok, location: @stockb }
      else
        format.html { render :edit }
        format.json { render json: @stockb.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /stockbs/1
  # DELETE /stockbs/1.json
  def destroy
    @stockb.destroy
    respond_to do |format|
      format.html { redirect_to stockbs_url, notice: "Stockb was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_stockb
    @stockb = Stockb.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def stockb_params
    params.require(:stockb).permit(:id, :partno, :kind, :indate, :num, :inprice, :irprice, :invalue, :irvalue, :outdate, :onum, :mno, :orprice, :orvalue, :itemno, :cordno, :updated_at, :memo, :cname, :sname, :novalid, :ikubun, :okubun, :created_at, :deleted_at)
  end
end
