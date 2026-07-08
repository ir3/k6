# frozen_string_literal: true

# 国籍登録
class RegistriesController < ApplicationController
  # GET /registries
  # GET /registries.json
  def index
    @registries = Registry.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @registries }
    end
  end

  # GET /registries/1
  # GET /registries/1.json
  def show
    @registry = Registry.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @registry }
    end
  end

  # GET /registries/new
  # GET /registries/new.json
  def new
    @registry = Registry.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @registry }
    end
  end

  # GET /registries/1/edit
  def edit
    @registry = Registry.find(params[:id])
  end

  # POST /registries
  # POST /registries.json
  def create
    @registry = Registry.new(params[:registry])

    respond_to do |format|
      if @registry.save
        format.html { redirect_to @registry, notice: 'Registry was successfully created.' }
        format.json { render json: @registry, status: :created, location: @registry }
      else
        format.html { render action: 'new' }
        format.json { render json: @registry.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /registries/1
  # PUT /registries/1.json
  def update
    @registry = Registry.find(params[:id])

    attrs = registry_params
    attrs[:deleted_at] = nil if attrs.delete(:clear_deleted) == "1"

    respond_to do |format|
      if @registry.update(attrs)
        format.html { redirect_to @registry, notice: 'Registry was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @registry.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH /registries/1/soft_delete
  def soft_delete
    @registry = Registry.find(params[:id])
    @registry.update(deleted_at: Time.current)
    redirect_to registries_url
  end

  private

  def registry_params
    params.require(:registry).permit(:country, :countryid, :rate, :deleted_at, :clear_deleted)
  end

  # DELETE /registries/1
  # DELETE /registries/1.json
  def destroy
    @registry = Registry.find(params[:id])
    @registry.update(deleted_at: Time.current)

    respond_to do |format|
      format.html { redirect_to registries_url }
      format.json { head :no_content }
    end
  end
end
