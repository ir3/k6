class UserProfilesController < ApplicationController
  before_action :set_user_profile, only: %i[ show edit update destroy ]
  before_action :require_admin, only: %i[ index destroy ]
  before_action :authorize_edit, only: %i[ edit update ]

  # GET /user_profiles (管理者のみ)
  def index
    @user_profiles = UserProfile.all
  end

  # GET /user_profiles/1
  def show
    @user = User.find(params[:id])
    @user_profile = @user.user_profile
  end

  # GET /user_profiles/new
  def new
    @user_profile = UserProfile.new
  end

  # GET /user_profiles/1/edit (管理者 or 自分のプロフィールのみ)
  def edit
    @user = User.find(params[:id])
    @user_profile = @user.user_profile
  end

  # POST /user_profiles
  def create
    @user_profile = UserProfile.new(user_profile_params)

    respond_to do |format|
      if @user_profile.save
        format.html { redirect_to @user_profile, notice: "User profile was successfully created." }
        format.json { render :show, status: :created, location: @user_profile }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @user_profile.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /user_profiles/1 (管理者 or 自分のプロフィールのみ)
  def update
    respond_to do |format|
      if @user_profile.update(user_profile_params)
        format.html { redirect_to @user_profile, notice: "プロフィールを更新しました。", status: :see_other }
        format.json { render :show, status: :ok, location: @user_profile }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @user_profile.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /user_profiles/1 (管理者のみ)
  def destroy
    @user_profile.destroy!

    respond_to do |format|
      format.html { redirect_to user_profiles_path, notice: "User profile was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private

    def set_user_profile
      @user_profile = UserProfile.find(params.expect(:id))
    end

    # 管理者のみ許可
    def require_admin
      unless admin?
        redirect_to root_path, alert: "管理者のみアクセスできます。"
      end
    end

    # 管理者 or 自分のプロフィールのみ編集可能
    def authorize_edit
      unless admin? || own_profile?
        redirect_to root_path, alert: "自分のプロフィールのみ編集できます。"
      end
    end

    def admin?
      Current.user.user_profile&.admin?
    end

    def own_profile?
      @user_profile.user_id == Current.user.id
    end

    # 管理者はstate含む全項目、一般ユーザは姓名のみ変更可能
    def user_profile_params
      if admin?
        params.fetch(:user_profile, {}).permit(:lastname, :firstname, :state)
      else
        params.fetch(:user_profile, {}).permit(:lastname, :firstname)
      end
    end
end
