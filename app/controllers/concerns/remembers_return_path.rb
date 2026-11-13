# frozen_string_literal: true

# メンテナンス画面（Ａ部品・Ｂ部品）の「戻る」の戻り先を覚える。
#
# 「戻る」を、ブラウザが送る直前のページ（Referer）にすると、画面で項目を1つ登録したあと
# （登録は、送信してから同じ画面に戻る作り）、直前のページが「この画面自身」になって、
# 注文部品詳細などに戻れなくなる。そこで、メンテナンス画面を開いたときの、直前のページを
# セッションに覚えておき、登録のあとも、それを戻り先にする。
#
# - 覚えるのは、同じサイトの、この画面自身でないページだけ（別のサイトのページや、この画面自身は覚えない）
# - 部品ごとに別々に覚える（別の部品の画面を開いても、上書きしない）。古いものから忘れる（最大 MAX 件。cookie を大きくしないため）
# - 戻り先が分からないとき（URL を直接開いたなど）は nil を返す（画面は、ブラウザの「戻る」にする）
module RemembersReturnPath
  extend ActiveSupport::Concern

  MAX = 20

  private

  # key: 画面ごとの印（例 "kepart_12"）。戻り先のパス（例 "/orders/5"）か nil を返す
  def return_path_for(key)
    paths = session[:return_paths].is_a?(Hash) ? session[:return_paths].dup : {}
    previous = previous_page_path
    if previous
      paths.delete(key) # 新しく覚えたものを、後ろ（新しい側）へ
      paths[key] = previous
      paths = paths.to_a.last(MAX).to_h
      session[:return_paths] = paths
    end
    paths[key]
  end

  # 直前のページのパス（クエリ付き）。同じサイトで、この画面自身でないときだけ。それ以外は nil
  def previous_page_path
    uri = begin
      URI.parse(request.referer.to_s)
    rescue URI::InvalidURIError
      nil
    end
    return nil unless uri&.host == request.host

    path = uri.path.to_s
    # 「//他のサイト」のような、別のサイトを指すパスは受け付けない
    return nil unless path.start_with?("/") && !path.start_with?("//")
    return nil if path == request.path

    uri.query.present? ? "#{path}?#{uri.query}" : path
  end
end
