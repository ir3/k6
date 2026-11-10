# frozen_string_literal: true

# システム管理画面（ナビバーの 管理者 → システム管理）。管理者のみ。
class SystemAdminController < ApplicationController
  before_action :require_admin

  # GET /system_admin
  def show
    @items = SystemInfo.items
  end

  private

    # 管理者のみ許可
    def require_admin
      unless Current.user.user_profile&.admin?
        redirect_to menu_path, alert: "管理者のみアクセスできます。"
      end
    end
end
