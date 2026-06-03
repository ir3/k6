# frozen_string_literal: true

class AdlistsController < ApplicationController
  before_action :require_authentication
  after_action :add_no, only: [:create]

  # GET /adlists
  # GET /adlists.json
  def index
    @keyword = params[:keyword]
    @new_order = params[:new_order]
    if @keyword && !@keyword.empty?
      @adlists = Adlist.find_by_sql("SELECT * FROM adlists WHERE ruby like '#{@keyword}%' ORDER BY id")
    else
      @adlists = Adlist.order('id').page params[:page]
    end

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render xml: @adlists }
      format.xlsx do
        send_data Adlist.xlsx_report,
                  filename: 'lists.xlsx',
                  type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      end
    end
  end

  # GET /adlists/search
  def search
    keyword = params[:keyword]
    if /[0-9]+/.match?(keyword)
      @adlists = Adlist.find_by_sql("SELECT * FROM adlists WHERE cozip7 like '#{keyword}%'")
    else
      @adlists = nil
      unless keyword.empty?
        where = "company like '%#{keyword}%'"
        adlists1 = Adlist.find_by_sql("SELECT * FROM adlists WHERE #{where} ORDER BY id")
        where2 = "coad1 like '%#{keyword}%'"
        adlists2 = Adlist.find_by_sql("SELECT * FROM adlists WHERE #{where2} ORDER BY id")
        where3 = "ruby like '%#{keyword}%'"
        adlists3 = Adlist.find_by_sql("SELECT * FROM adlists WHERE #{where3} ORDER BY id")
        where4 = "coad2 like '%#{keyword}%'"
        adlists4 = Adlist.find_by_sql("SELECT * FROM adlists WHERE #{where4} ORDER BY id")
        where5 = "section like '%#{keyword}%'"
        adlists5 = Adlist.find_by_sql("SELECT * FROM adlists WHERE #{where5} ORDER BY id")
        where6 = "name like '%#{keyword}%'"
        adlists6 = Adlist.find_by_sql("SELECT * FROM adlists WHERE #{where6} ORDER BY id")
        @adlists = if adlists1
                     if adlists2
                       adlists1 | adlists2
                     else
                       adlists1
                                end
                   else
                     adlists2
                   end
        @adlists |= adlists3 if adlists3
        @adlists |= adlists4 if adlists4
        @adlists |= adlists5 if adlists5
        @adlists |= adlists6 if adlists6

        # idだけ取り出して保存
        @ids = []
        @adlists.each do |adlist|
          @ids << adlist.id
        end
        logger.debug  @ids
        cookies[:ids] = @ids
      end
    end

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render xml: @adlists }
      format.json { render json: @adlist }
      format.xlsx do
        send_data Adlist.xlsx_report,
                  filename: 'lists.xlsx',
                  type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      end
    end
  end

  # GET /adlists/1
  # GET /adlists/1.json
  def show
    @adlist = Adlist.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @adlist }
    end
  end

  # GET /adlists/new
  # GET /adlists/new.json
  def new
    @adlist = Adlist.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @adlist }
    end
  end

  # GET /adlists/1/edit
  def edit
    @adlist = Adlist.find(params[:id])
  end

  # POST /adlists
  # POST /adlists.json
  def create
    params.permit!
    @adlist = Adlist.new(params[:adlist])

    #     @p = (params[:adlist])
    #     @adlist.ruby    = @p.ruby
    #     @adlist.company = @p.company
    #     @adlist.section = @p.section
    #     @adlist.section2= @p.section2
    #     @adlist.cozip7  = @p.cozip7
    #     @adlist.coad1   = @p.coad1
    #     @adlist.coad2   = @p.coad2
    #     @adlist.coad3   = @p.coad3
    #     @adlist.cotel   = @p.cotel
    #     @adlist.cofax   = @p.cofax
    #     @adlist.comail  = @p.comail
    #     @adlist.copok   = @p.copok
    #     @adlist.courl   = @p.courl
    #     @adlist.comobile= @p.comobile
    #     @adlist.memo    = @p.memo
    #     @adlist.name    = @p.name
    #     @adlist.position= @p.position
    #     @adlist.zip7    = @p.zip7
    #     @adlist.address1= @p.address1
    #     @adlist.address2= @p.address2
    #     @adlist.address3= @p.address3
    #     @adlist.email   = @p.email
    #     @adlist.tel     = @p.tel
    #     @adlist.fax     = @p.fax
    #     @adlist.mtel    = @p.mtel
    #     @adlist.url     = @p.url

    respond_to do |format|
      if @adlist.save
        format.html { redirect_to @adlist, notice: 'Adlist was successfully created.' }
        format.json { render json: @adlist, status: :created, location: @adlist }
      else
        format.html { render action: 'new' }
        format.json { render json: @adlist.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /adlists/1
  # PUT /adlists/1.json
  def update
    @adlist = Adlist.find(params[:id])

    respond_to do |format|
      #      if @adlist.update_attributes(params[:adlist])
      if @adlist.update(adlist_params)
        format.html { redirect_to @adlist, notice: 'Adlist was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @adlist.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /adlists/1
  # DELETE /adlists/1.json
  def destroy
    @adlist = Adlist.find(params[:id])
    @adlist.destroy

    respond_to do |format|
      format.html { redirect_to adlists_url }
      format.json { head :no_content }
    end
  end

  # post /adlists/out
  def out
    logger.debug cookies[:ids]
    redirect_to adlists_url unless cookies[:ids]
    p = Axlsx::Package.new
    wb = p.workbook
    wb.add_worksheet(name: '一覧') do |sheet|
      sheet.add_row ['■', '一覧']
      sheet.add_row ['＃', '名前', '組織', '〒', '住所', '作成日', '更新日']
      adlists = []
      cookies[:ids].split('&').each do |id|
        adlists << Adlist.find(id)
      end
      adlists.each do |adlist|
        org = adlist.company || ''
        org << adlist.section if adlist.section
        org << adlist.section2 if adlist.section2
        address = adlist.address1 || ' '
        address << adlist.address2 if adlist.address2
        address << adlist.address3 if adlist.address3
        address << adlist.coad1 if adlist.coad1
        address << adlist.coad2 if adlist.coad2
        address << adlist.coad3 if adlist.coad3
        sheet.add_row [adlist.id, adlist.name, org, adlist.cozip7, address, adlist.created_at.strftime('%Y/%m/%d %H:%M'), adlist.updated_at.strftime('%Y/%m/%d %H:%M')]
      end
    end

    file_path = File.join(Rails.root, 'tmp', 'tatelist.xlsx')
    logger.info file_path
    p.serialize file_path
    filename = ERB::Util.url_encode("#{Time.now.strftime('%Y%m%d%H%M')}一覧.xlsx")
    send_file(file_path, filename: filename)
  end

  # post /adlists/select
  def select
    logger.debug cookies[:selids]
    #    unless cookies[:selids]
    #      redirect_to adlists_url
    #    end
    @adlists = []
    params[:selids].each do |id, _flag|
      logger.debug id
      @adlists << Adlist.find(id.to_i)
    end

    # idだけ取り出して保存
    @ids = []
    @adlists.each do |adlist|
      @ids << adlist.id
    end
    logger.debug  @ids
    cookies[:ids] = @ids
    #    redirect_to controller: "adlists", action: "search" and return

    respond_to do |format|
      format.html # index.html.erb
    end
  end

  private

  # Never trust parameters from the scary internet, only allow the white list through.
  def adlist_params
    params.require(:adlist).permit(:no, :ruby, :company, :section, :section2,
                                   :cozip7, :coad1, :coad2, :coad3, :cotel, :cofax, :comail,
                                   :copok, :courl, :comobile, :memo,
                                   :name, :position, :zip7, :address1, :address2, :address3,
                                   :email, :tel, :fax, :mtel, :url,
                                   :kbn, :gender, :birthday, :kbirthday)
  end

  # 新規関係先作成時にidからnoも作成する
  def add_no
    @adlist.no    = @adlist.id
    @adlist.kbn   = @adlist.ruby[0]
    @adlist.update(adlist_params)
    logger.debug 'create後の処理'
    logger.debug @adlist.ruby
    logger.debug @adlist.ruby[0]
  end
end
