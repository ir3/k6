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
  def edit
    @orderpart = Orderpart.find(params[:id])
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
  # PUT /orderparts/1.json
  def update
    @orderpart = Orderpart.find(params[:id])

    respond_to do |format|
      #      if @orderpart.update_attributes(params[:orderpart])
      if @orderpart.update(orderpart_params)
        format.html { redirect_to @orderpart, notice: 'Orderpart was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @orderpart.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /orderparts/1
  # DELETE /orderparts/1.json
  def destroy
    @orderpart = Orderpart.find(params[:id])
    @orderpart.destroy

    respond_to do |format|
      format.html { redirect_to orderparts_url }
      format.json { head :no_content }
    end
  end
end
