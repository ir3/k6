class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]

  def new
  end

  def create
    if user = User.find_by(email_address: params[:email_address])
      token = user.generate_token_for(:password_reset)
      reset_url = edit_password_url(token)
      redirect_to new_session_path, notice: "パスワードリセットURL: #{reset_url}"
    else
      redirect_to new_password_path, alert: "そのメールアドレスのユーザが見つかりません。"
    end
  end

  def edit
  end

  def update
    if @user.update(params.permit(:password, :password_confirmation))
      redirect_to new_session_path, notice: "パスワードを変更しました。"
    else
      redirect_to edit_password_path(params[:token]), alert: "パスワードが一致しません。"
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_password_path, alert: "リセットリンクが無効または期限切れです。"
    end
end
