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
end
