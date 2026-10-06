# frozen_string_literal: true

class OrderpartsController < ApplicationController
  # GET /orderparts
  # GET /orderparts.json
  def index
    @keyword = params[:keyword]
    if @keyword && !@keyword.empty?
      logger.debug  @keyword
      @orderparts = Orderpart.find_by_sql("SELECT * FROM orderparts WHERE pcode like '#{keyword}%' ORDER BY id DESC")
    else
      @orderparts = Orderpart.order('id').page params[:page]
    end

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @orderparts }
    end
  end

  # POST /orderparts/search
  def search
    keyword = params[:keyword]
    keykind = params[:keykind]
    logger.debug  keyword
    logger.debug  keykind
    if keykind
      @orderparts = Orderpart.find_by_sql("SELECT * FROM orderparts WHERE (deleted_at IS NULL) AND #{keykind} like '#{keyword}%' ORDER BY id DESC")
    elsif /¥d./.match?(keyword)
      @orderparts = Orderpart.find_by_sql("SELECT * FROM orderparts WHERE (deleted_at IS NULL) AND mno like '#{keyword}%' ORDER BY id DESC")
    else
      @orderparts = Orderpart.find_by_sql("SELECT * FROM orderparts WHERE (deleted_at IS NULL) AND info like '%#{keyword}%' ORDER BY id DESC")
    end

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render xml: @orderparts }
      format.json { render json: @orderparts }
    end
  end

  # GET /orderparts/1
  # GET /orderparts/1.json
  def show
    if params[:id] == 'search'
      redirect_to action: 'index'
    else
      @orderpart = Orderpart.find(params[:id])
      respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @orderpart }
      end
    end
  end

  # GET /orderparts/new
  # GET /orderparts/new.json
  def new
    @orderpart = Orderpart.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @orderpart }
    end
  end

  # GET /orderparts/1/edit
  # 注文部品詳細編集（旧 partsin2.asp）。注文部品詳細の「順」から開く
  def edit
    @orderpart = Orderpart.find(params[:id])
    prepare_edit_screen
  end

  # POST /orderparts
  # POST /orderparts.json
  def create
    @orderpart = Orderpart.new(params[:orderpart])

    respond_to do |format|
      if @orderpart.save
        format.html { redirect_to @orderpart, notice: 'Orderpart was successfully created.' }
        format.json { render json: @orderpart, status: :created, location: @orderpart }
      else
        format.html { render action: 'new' }
        format.json { render json: @orderpart.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /orderparts/1
  # 編集画面のフォームから、順・ItemNo・備考・数量・バラ売り数量を1項目ずつ登録する
  def update
    @orderpart = Orderpart.find(params[:id])
    result = OrderpartEditor.new(@orderpart, params.fetch(:orderpart, {}).permit(*OrderpartEditor::LABELS.keys)).call

    if result.success?
      # 更新(POST+_method)のリダイレクトは 303 にする（Turbo/fetch が元のメソッドのまま追従しないように）
      redirect_to edit_orderpart_path(@orderpart), status: :see_other, notice: "#{result.label}を登録しました。"
    else
      @orderpart.reload
      prepare_edit_screen
      flash.now[:alert] = result.error
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /orderparts/1
  # 「この部品を削除する」。部品明細の行を物理削除して、注文部品詳細に戻る（旧ASPの注文削除と同じ扱い）
  def destroy
    @orderpart = Orderpart.find(params[:id])
    order = Order.find_by(mno: @orderpart.mno)
    @orderpart.destroy!

    redirect_to(order ? order_path(order) : orders_path, status: :see_other,
                notice: "部品 #{@orderpart.partno}#{@orderpart.kzaiko} を削除しました。")
  end

  private

  # 編集画面に出す、注文・部品台帳の情報
  def prepare_edit_screen
    @order = Order.find_by(mno: @orderpart.mno)
    @part = @orderpart.master_part
    @part_path = @part.is_a?(Kepart) ? kepart_path(@part) : part_path(@part) if @part
    @name = part_name(@part)
  end

  # 注文の船籍が日本なら和文名称、それ以外は英文名称（partsin2.asp と同じ）。無ければもう一方
  def part_name(part)
    return nil unless part

    japanese = @order&.country.to_s.start_with?("日")
    (japanese ? [ part.jname, part.ename ] : [ part.ename, part.jname ]).find(&:present?)
  end
end
