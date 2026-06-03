# frozen_string_literal: true

class PartsController < ApplicationController
  before_action :require_authentication

  # GET /parts
  # GET /parts.json
  def index
    @keyword = params[:keyword]
    if @keyword && !@keyword.empty?
      @parts = Part.find_by_sql("SELECT * FROM parts WHERE pcode like '#{@keyword}%' ORDER BY id")
    else
      @parts = Part.order('id').page params[:page]
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
  def show
    @part = Part.find(params[:id])

    @num = 0
    @stocks = Stock.where(partno: @part.pcode)
    @stocks.each do |stock|
      @num += stock.num
    end
    @stock = Stock.new

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @part }
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
  def destroy
    @part = Part.find(params[:id])
    @part.destroy

    respond_to do |format|
      format.html { redirect_to parts_url }
      format.json { head :no_content }
    end
  end
end
