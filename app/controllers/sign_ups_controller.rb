class SignUpsController < ApplicationController
  allow_unauthenticated_access only: %i[ show create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to sign_up_path, alert: "Try again later." }

  def show
    redirect_to users_path and return if authenticated?
    @user = User.new
  end

  def create
    @user = User.new(sign_up_params)
    if @user.save
      start_new_session_for(@user)
      redirect_to controller: :users, action: :index
    else
      render :show, status: :unprocessable_entity
    end
  end

  private
    def sign_up_params
      params.expect(user: [:email_address, :password, :password_confirmation ])
    end
end