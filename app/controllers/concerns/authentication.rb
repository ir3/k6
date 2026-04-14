# moduleは再利用したい機能をまとめる箱のようなもの。
# includeやextendすることで機能を使えるようになる。
# 認証ジェネレータではApplicationControllerにてAuthenticationをincludeしている。
module Authentication
  # concernはmoduleと同様に共通処理をまとめるもの。
  # concernによってincluded do ... end が使えるのでincludeされたときの処理をまとめられる。
  extend ActiveSupport::Concern

  included do
    # 全てのactionの前に認証確認を行う。
    before_action :require_authentication
    # helper_methodは、controllerで定義したメソッドをviewでも呼べる。
    helper_method :authenticated?
  end

  class_methods do
    # **optionsで指定したアクションでは認証確認をスキップする。
    # 例）allow_unauthenticated_access only: [ :index ]
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end

    # **optionsで指定したアクションでは、未認証ユーザのみアクセスできる。
    def unauthenticated_access_only(**options)
      allow_unauthenticated_access **options
      before_action -> { redirect_to root_path if authenticated? }, **options
    end
  end

  private
    # 認証確認のメソッド。deviseのuser_sign_in?メソッドに相当。
    def authenticated?
      resume_session
    end

    # before_actionで実行されるメソッド。
    def require_authentication
      resume_session || request_authentication
    end

    # Current.sessionがtrueならログイン済みと判定される。
    # falseやnilならfind_session_by_cookieの結果をCurrent.sessionに代入する。
    # X = X || Y と同じ意味の記述方法。
    # Current.sessionは、start_new_session_forで作成される。
    def resume_session
      Current.session ||= find_session_by_cookie
    end

    # ブラウザのCookieからsession_idを取り出し、改竄がなければSessionモデルから該当のIDを検索してreturnする。
    # if以降がtrueでなければ改竄の可能性あり。
    def find_session_by_cookie
      Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to new_session_path
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || root_url
    end

    def start_new_session_for(user)
      # user_agentは、クライアントのブラウザやOS等の情報。
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
      end
      begin
       Current.user.user_profile.sign_in_at = Time.current
       Current.user.user_profile.save!
      rescue 
        Rails.logger.info("Created UserProfile for sign_in_at")
        user_profile = UserProfile.new
        user_profile.user_id = Current.user.id
        user_profile.sign_in_at = Time.current
        user_profile.state = "online"
        user_profile.save!
      end
    end

    def terminate_session
      Current.user.user_profile.sign_out_at = Time.current
      Current.user.user_profile.save!
      Current.session.destroy
      cookies.delete(:session_id)
    end
end