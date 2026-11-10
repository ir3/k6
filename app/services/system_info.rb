# frozen_string_literal: true

require "json"

# システム管理画面に出す、ソフトウェアのバージョン情報を集める。
#
# 取得元は項目ごとに違う。本番ではNodeはビルド（yarn install / assets:precompile）専用で、
# Pumaを動かすsystemdのPATHにnodenvが入っていないため、動いているプロセスから `node -v` は呼べない
# （DEPLOY.md 参照）。そこで次のように、どの環境でも同じ方法で読めるものから取る。
#
#   Ruby / Rails ........... 動いているプロセス自身の値（RUBY_VERSION / Rails.version）
#   Node.js ................ .node-version（デプロイで入れるバージョンの正。DEPLOY.md 参照）
#   Tailwind CSS / daisyUI . node_modules に入っているパッケージの package.json（yarn install 済みの版）
#
# 読めなかった項目は version を nil にして返す（画面側で「不明」と出す）。
# 状態を見るだけの画面なので、ファイルが無い・壊れているくらいで画面ごと落とさない。
module SystemInfo
  Item = Data.define(:name, :version, :source)

  module_function

  def items(root: Rails.root)
    root = Pathname(root)
    [
      Item.new("Ruby", RUBY_VERSION, "実行中のプロセス"),
      Item.new("Rails", Rails.version, "実行中のプロセス"),
      Item.new("Node.js", read_text(root.join(".node-version")), ".node-version"),
      Item.new("Tailwind CSS", npm_package_version(root, "tailwindcss"), "node_modules"),
      Item.new("daisyUI", npm_package_version(root, "daisyui"), "node_modules")
    ]
  end

  # テキストファイルの中身（前後の空白を除く）。無い・空なら nil
  def read_text(path)
    text = File.read(path).strip
    text.empty? ? nil : text
  rescue SystemCallError
    nil
  end

  # node_modules/<パッケージ名>/package.json の "version"。読めなければ nil
  def npm_package_version(root, package_name)
    json = JSON.parse(File.read(root.join("node_modules", package_name, "package.json")))
    version = json["version"] if json.is_a?(Hash)
    version.is_a?(String) && !version.empty? ? version : nil
  rescue SystemCallError, JSON::ParserError
    nil
  end
end
