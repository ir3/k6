# frozen_string_literal: true

class OrdersController < ApplicationController
  before_action :require_authentication

  # GET /orders
  # GET /orders.json
  def index
    @shipname = params[:shipname]
    @engno    = params[:engno]
    @keyword  = params[:keyword]
    @keykind  = params[:keykind]
    logger.debug  @keyword
    logger.debug  @keykind
    if params[:mno_order]
      if session[:mno_order] == 'DESC'
        session[:mno_order] = 'ASC'
      elsif session[:mno_order] == 'ASC'
        session[:mno_order] = 'DESC'
      end
    else
      session[:mno_order] = 'ASC'
    end
    mno_order = session[:mno_order]
    ym = Time.now.strftime('%Y%m')
    session[:keyword] = nil
    session[:keykind] = nil
    session[:shipname] = nil
    session[:engno] = nil
    if @keyword && !@keyword.empty?
      session[:keyword] = @keyword.to_s
      logger.debug session[:keyword]
      if (@keyword == 'next') || (@keyword == 'last') || (@keyword == 'now')
        if session[:yearmonth] && !session[:yearmonth].empty? && @keyword != 'now'
          ym = session[:yearmonth]
        end
        date = Date.parse(ym + '01')
        if @keyword == 'next'
          ym = date.next_month.strftime('%Y%m')
        elsif @keyword == 'last'
          ym = date.last_month.strftime('%Y%m')
        end
        @orders = Order.joins(:adlists).find_by_sql("SELECT * FROM orders WHERE (deleted_at IS NULL) AND mno like '#{ym}%' ORDER BY id #{mno_order}")
        @search_condition = "対象年月: #{ym}"
      elsif @keykind == 'companyid'
        session[:keykind] = @keykind.to_s
        @orders = Order.where('adlist_id = ?', @keyword).order("id #{mno_order}")
        @search_condition = "取引先ID: #{@keyword}"
      else
        @orders = Order.find_by_sql("SELECT * FROM orders WHERE (deleted_at IS NULL) AND mno like'%#{@keyword}%' ORDER BY id #{mno_order}")
        @search_condition = "取引番号: #{@keyword}"
      end
    elsif @shipname && !@shipname.empty?
      session[:shipname] = @shipname.to_s
      @orders = Order.find_by_sql("SELECT * FROM orders WHERE (deleted_at IS NULL) AND shipname like'#{@shipname}%' ORDER BY id #{mno_order}")
      @search_condition = "船名: #{@shipname}"
    elsif @engno && !@engno.empty?
      session[:engno] = @engno.to_s
      @orders = Order.find_by_sql("SELECT * FROM orders WHERE (deleted_at IS NULL) AND engno like'#{@engno}%' ORDER BY id #{mno_order}")
      @search_condition = "機番: #{@engno}"
    else
      ym = session[:yearmonth] if session[:yearmonth]
      @orders = Order.joins(:adlists).find_by_sql("SELECT * FROM orders WHERE (deleted_at IS NULL) AND mno like '#{ym}%' ORDER BY id #{mno_order}")
      @search_condition = "対象年月: #{ym}"
    end
    session[:yearmonth] = ym
    @orders = paginate_orders(@orders)

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @orders }
    end
  end

  # GET/POST /orders/alllist
  def alllist
    if request.post?
      redirect_to orders_alllist_path(smno: params[:SMNo], fixed: params[:fixed])
      return
    end

    smno  = params[:smno].to_s
    smno  = session[:smno].to_s if smno.empty?
    session[:smno] = smno unless smno.empty?

    fixed = params[:fixed].to_i
    label = fixed == 1 ? "受注決定分" : "未受決分"

    base = Order.where("deleted_at IS NULL")
                .where("CAST(mno AS TEXT) LIKE ?", "#{smno}%")
                .order(:mno)

    @orders = if fixed == 1
      base.where("orderitem LIKE ?", "%（受注）%")
    else
      base.where("orderitem NOT LIKE ? OR orderitem IS NULL", "%（受注）%")
    end
    @orders = paginate_orders(@orders)
    @title = "#{smno} #{label}"
    @search_condition = @title
  end

  # GET/POST /orders/search
  def search
    # TurboはPOSTフォームの応答にリダイレクトを要求するため、
    # POST時はGETへリダイレクトしてから描画する(Post/Redirect/Getパターン)。
    if request.post?
      redirect_to orders_search_path(keyword: params[:keyword], keykind: params[:keykind])
      return
    end

    keyword = params[:keyword]
    keykind = params[:keykind]
    logger.debug  keyword
    logger.debug  keykind
    keykind_labels = { "etype" => "形式検索", "engno" => "機番検索", "shipname" => "船名検索", "company" => "会社名検索", "memo" => "メモ検索" }
    if keykind && !keykind.empty?
      if keykind == 'company'
        adlist_id = Adlist.find_by_sql("SELECT * FROM adlists WHERE (deleted_at IS NULL) AND #{keykind} like '%#{keyword}%'").first
        @orders = Order.where('adlist_id = ?', adlist_id.id)
      else
        @orders = Order.find_by_sql("SELECT * FROM orders WHERE (deleted_at IS NULL) AND #{keykind} like '%#{keyword}%'")
      end
      @search_condition = "#{keykind_labels[keykind] || keykind}: #{keyword}"
    elsif
      session[:yearmonth] = keyword
      @orders = Order.find_by_sql("SELECT * FROM orders WHERE (deleted_at IS NULL) AND mno like '#{keyword}%'")
      @search_condition = "取引番号: #{keyword}"
    end
    @orders = paginate_orders(@orders)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render xml: @parts }
      format.json { render json: @parts }
    end
  end

  # POST /orders/copy
  def copy
    @order = Order.new
    @ori   = Order.find(session[:order_id])
    @order.mno        = newmno
    @order.st         = @ori.st
    @order.adlist_id  = @ori.adlist_id
    @order.rdate      = nil
    @order.ncomment   = @ori.ncomment
    @order.ndate      = @ori.ndate
    @order.nplase     = @ori.nplase
    @order.ldate      = @ori.ldate
    @order.tcondition = @ori.tcondition
    @order.etype      = @ori.etype
    @order.engno      = @ori.engno
    @order.shipname   = @ori.shipname
    @order.country    = @ori.country
    @order.pnum       = @ori.pnum
    @order.inspection = @ori.inspection
    @order.hno        = @ori.hno
    @order.orderitem  = newmno.to_s[4, 5]
    @order.memo       = nil
    @order.tname      = @ori.tname
    @order.idate      = @ori.idate
    @order.odate      = @ori.odate
    @order.mdate      = @ori.mdate
    @order.irate      = @ori.irate
    @order.nebiki     = @ori.nebiki
    @order.irate2     = @ori.irate2
    @order.tc         = @ori.tc
    @order.tcno       = @ori.tcno
    @order.zp         = @ori.zp
    @order.zpno       = @ori.zpno
    @order.glc        = @ori.glc
    @order.glcno      = @ori.glcno
    @order.mg         = @ori.mg
    @order.mgno       = @ori.mgno
    @order.ono        = @ori.ono
    @order.mitday     = @ori.mitday
    @order.syuday     = @ori.syuday
    @order.mitday     = @ori.mitday
    @order.seiday     = @ori.seiday

    @order.save
    # 部品詳細も複製
    oriparts = Orderpart.find_by_sql("SELECT * FROM orderparts WHERE mno=#{@ori.mno}")
    oriparts.each do |oripart|
      orderpart = Orderpart.new
      orderpart.mno    = @order.mno
      orderpart.sno    = oripart.sno
      orderpart.itemno = oripart.itemno
      orderpart.cordno = oripart.cordno
      orderpart.partno = oripart.partno
      orderpart.info   = oripart.info
      orderpart.qty    = oripart.qty
      orderpart.unitpd = oripart.unitpd
      orderpart.unitpi = oripart.unitpi
      orderpart.unitpi2 = oripart.unitpi2
      orderpart.irate  = oripart.irate
      orderpart.totala = oripart.totala
      orderpart.total2 = oripart.total2
      orderpart.ndate  = oripart.ndate
      orderpart.unitweight = oripart.unitweight
      orderpart.totalweight = oripart.totalweight
      orderpart.save
    end

    redirect_to "/orders/#{@order.id}"
  end

  # POST /orders/keycopy
  def keycopy
    @order = Order.new
    @ori   = Order.find(session[:order_id])
    @order.mno        = newmno
    @order.st         = @ori.st
    @order.adlist_id  = @ori.adlist_id
    @order.rdate      = nil
    @order.ncomment   = @ori.ncomment
    @order.ndate      = @ori.ndate
    @order.nplase     = @ori.nplase
    @order.ldate      = @ori.ldate
    @order.tcondition = @ori.tcondition
    @order.etype      = @ori.etype
    @order.engno      = @ori.engno
    @order.shipname   = @ori.shipname
    @order.country    = @ori.country
    @order.pnum       = nil
    @order.inspection = @ori.inspection
    @order.hno        = @ori.hno
    @order.orderitem  = newmno.to_s[4, 5]
    @order.memo       = nil
    @order.tname      = @ori.tname
    @order.idate      = @ori.idate
    @order.odate      = @ori.odate
    @order.mdate      = @ori.mdate
    @order.irate      = @ori.irate
    @order.nebiki     = @ori.nebiki
    @order.irate2     = @ori.irate2
    @order.tc         = @ori.tc
    @order.tcno       = @ori.tcno
    @order.zp         = @ori.zp
    @order.zpno       = @ori.zpno
    @order.glc        = @ori.glc
    @order.glcno      = @ori.glcno
    @order.mg         = @ori.mg
    @order.mgno       = @ori.mgno
    @order.ono        = @ori.ono
    @order.mitday     = @ori.mitday
    @order.syuday     = @ori.syuday
    @order.mitday     = @ori.mitday
    @order.seiday     = @ori.seiday

    @order.save
    redirect_to "/orders/#{@order.id}"
  end

  # POST /orders/ocopy
  def ocopy
    adlist_id = params[:adlist_id]
    @order = Order.new
    @order.mno        = newmno
    @order.adlist_id  = adlist_id

    @order.save
    redirect_to "/orders/#{@order.id}/edit"
  end

  # GET /orders/1
  # GET /orders/1.json
  def show
    @order = Order.find(params[:id])
    session[:order_id] = @order.id
    session[:mno] = @order.mno
    # @orderparts = Orderpart.find_by_sql("SELECT * FROM orderparts WHERE (deleted_at IS NULL) AND mno=#{@order.mno}")
    @orderparts = Orderpart.where(mno: @order.mno).order(:sno)

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @order }
    end
  end

  # GET /orders/new
  # GET /orders/new.json
  def new
    @order = Order.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @order }
    end
  end

  # GET /orders/1/edit
  def edit
    @order = Order.find(params[:id])
    @orderparts = Orderpart.where(mno: @order.mno).order(:sno)
  end

  # POST /orders
  # POST /orders.json
  def create
    @order = Order.new(params[:order])

    respond_to do |format|
      if @order.save
        format.html { redirect_to @order, notice: 'Order was successfully created.' }
        format.json { render json: @order, status: :created, location: @order }
      else
        format.html { render action: 'new' }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /orders/1
  # PUT /orders/1.json
  def update
    @order = Order.find(params[:id])

    respond_to do |format|
      #      if @order.update_attributes(params[:order])
      if @order.update(order_params)
        format.html { redirect_to @order, notice: 'Order was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /orders/1
  # DELETE /orders/1.json
  def destroy
    @order = Order.find(params[:id])
    #    @order.destroy
    @orderparts = Orderpart.where(mno: @order.mno)
    @orderparts.each(&:soft_destroy!)
    @order.soft_destroy!

    respond_to do |format|
      format.html { redirect_to orders_url }
      format.json { head :no_content }
    end
  end

  private

  # find_by_sql の結果（配列）と ActiveRecord::Relation のどちらでもページネーションできるようにする
  def paginate_orders(orders)
    if orders.is_a?(ActiveRecord::Relation)
      orders.page(params[:page])
    else
      Kaminari.paginate_array(orders).page(params[:page])
    end
  end

  # 新規に取引管理No.作成
  def newmno
    # MNo最新＝最大をselect
    maxmno = Order.maximum(:mno).to_i

    # 現在の年・月
    nyear  = Time.now.to_s[0..4].to_i
    nmonth = Time.now.to_s[5..6].to_i
    nyearmonth = nyear * 100_000 + nmonth * 1000

    # 月代わり判定し取引管理No.(MNo)決定
    mno = if maxmno < nyearmonth
            nyearmonth + 1
          else
            maxmno + 1
          end
    mno
  end

  def order_params
    params.require(:order).permit(:shipname, :engno, :orderitem, :memo, :ono, :etype,
                                  :country, :tc, :tcno, :zp, :zpno, :glc, :glcno, :mg,
                                  :mgno, :rdate, :ncomment, :irate, :irate2, :nebiki)
  end
end
