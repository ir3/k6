module ApplicationHelper
  # ナビバー見出し・タブタイトル(<title>)の両方で使う画面名。
  # controller/action固有の表示が無ければ各画面のcontent_for(:page_title)を使う。
  def screen_title
    return "業務システム" if controller_name == "menus"
    return "注文部品詳細" if controller_name == "orders" && action_name == "show"
    return "取引台帳" if controller_name == "orders"

    content_for(:page_title)
  end
end
