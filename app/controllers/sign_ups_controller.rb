class SignUpsController < ApplicationController
  allow_unauthenticated_access only: %i[ show create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to sign_up_path, alert: "Try again later." }

  def show
    redirect_to new_session_path and return if !authenticated? && cookies[:known_user].present?

    @user = User.new
  end

  def create
    @user = User.new(sign_up_params)
    if @user.save
      start_new_session_for(@user)
      redirect_to welcom_index_path
    else
      render :show, status: :unprocessable_entity
    end
  end

  private
    def sign_up_params
      params.expect(user: [:email_address, :password, :password_confirmation ])
    end
end