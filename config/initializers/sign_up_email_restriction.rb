# frozen_string_literal: true

# k6独自の制限: 自己登録（sign_up）はkobeengine.comドメインのメールアドレスのみ許可する。
# 管理者による作成など、他のユーザー作成経路には影響しない。
#
# app/controllers/sign_ups_controller.rb はk2（ベースリポジトリ）側でも継続的に
# 更新されるファイルなので、直接編集せずここから外付けでbefore_actionを追加する。
# これによりk2からの取り込み（git merge）時にsign_ups_controller.rbがコンフリクトすることはない。
Rails.application.config.to_prepare do
  SignUpsController.class_eval do
    before_action :restrict_sign_up_email_domain, only: :create

    private

    def restrict_sign_up_email_domain
      # ログイン中（管理者がユーザ一覧からユーザ追加する場合など）は制限しない。
      return if authenticated?

      allowed_domain = "kobeengine.com"
      email = params.dig(:user, :email_address).to_s.strip.downcase
      return if email.end_with?("@#{allowed_domain}")

      @user = User.new(sign_up_params)
      @user.errors.add(:email_address, "は許可されたアドレスのみ登録できます")
      render :show, status: :unprocessable_entity
    end
  end
end
