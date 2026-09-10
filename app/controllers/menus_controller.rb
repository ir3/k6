# frozen_string_literal: true

class MenusController < ApplicationController
  allow_unauthenticated_access only: :index

  def index
    session[:visited_menu] = true
    unless session[:ymd]
      ymd = Time.now.strftime('%Y/%m/%d')
      session[:ymd] = ymd
    end
    unless session[:yearmonth]
      session[:yearmonth] = Time.now.strftime('%Y%m')
    end
  end

  def update_tax_rate
    unless Current.user.user_profile&.read_attribute_before_type_cast(:state).to_i > 1
      return redirect_to menu_path, alert: "管理者のみ変更できます"
    end

    Ksystem.set("default_tax_rate", params[:default_tax_rate])
    redirect_to menu_path, notice: "消費税率(全体デフォルト)を更新しました"
  end
end
