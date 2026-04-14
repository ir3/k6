class UsersController < ApplicationController
  before_action :set_user, only: %i[ show edit update destroy ]

  # GET /users or /users.json
  def index
    if Current.user.user_profile.read_attribute_before_type_cast(:state) > 1
      @users = User.all
    else
      @users = User.where(id: Current.user.id)
    end
  end

  # GET /users/1 or /users/1.json
  def show
    if Current.user.user_profile.read_attribute_before_type_cast(:state) > 1
      @user = User.find(params[:id])
    else
      @user = Current.user
    end
  end

  # GET /users/new
  def new
    @user = User.new
  end

  # GET /users/1/edit
  def edit
    @user = User.find(params[:id])
    @user_profile = @user.user_profile
  end

  # POST /users or /users.json
  def create
    @user = User.new(user_params)

    respond_to do |format|
      if @user.save
        format.html { redirect_to @user, notice: "User was successfully created." }
        format.json { render :show, status: :created, location: @user }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /users/1 or /users/1.json
  def update
    respond_to do |format|
      if @user.update(user_params)
        format.html { redirect_to @user, notice: "User was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @user }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /users/1 or /users/1.json
  def destroy
    #@user.destroy!
    @user.user_profile.state = "offline"
    @user.user_profile.save!
    respond_to do |format|
      format.html { redirect_to users_path, notice: "User was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  def delete
    @user.user_profile.state = "offline"
    @user.user_profile.save!
    respond_to do |format|
      format.html { redirect_to users_path, notice: "User was successfully offlined.", status: :see_other }
      format.json { head :no_content }
    end
    redirect_to(root_url)
  end
  
  private
    # Use callbacks to share common setup or constraints between actions.
    def set_user
      @user = User.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def user_params
      params.require(:user).permit(:email_address)
    end

    # beforeフィルター
    # 正しいユーザーかどうかを確認
    def correct_user
      @user = User.find(params[:id])
      redirect_to(root_url) unless current_user?(@user)
    end

    # 管理者かどうかを確認
    def admin_user
      @user =  Current.user
      redirect_to(root_url) unless @user.user_profile.read_attribute_before_type_cast(:state) > 1
  #    redirect_to(root_url) unless current_user.admin?
    end
end
