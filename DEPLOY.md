# デプロイ手順（ConoHa本番）

Docker・Kamalは使わず、systemd + nginx の直接実行。

## 前提

- サーバー: ConoHa、作業ディレクトリ `/var/www/k6`
- Rails Puma は systemd ユニット `k6.service` で常駐
- Ruby/Node は anyenv 配下の rbenv/nodenv で管理（`/opt/anyenv/`）

## 通常のデプロイ手順

```bash
cd /var/www/k6
git pull
bundle install

# Rails本番環境変数をこのシェルにも読み込む（systemdのk6.serviceと同じ値）
for kv in $(sudo systemctl show k6 --property=Environment | sed 's/^Environment=//'); do export "$kv"; done

# node/yarnをPATHに通す（systemdのPATHには含まれていないため）
export PATH="/opt/anyenv/envs/nodenv/shims:/opt/anyenv/envs/nodenv/bin:$PATH"

# アセットビルド + フィンガープリント生成（cssやjsを変更した場合は必須）
yarn install
cp app/assets/stylesheets/k.css app/assets/builds/k.css
RAILS_ENV=production bin/rails assets:precompile

# マイグレーションがあれば
RAILS_ENV=production bin/rails db:migrate

# Pumaへ反映
sudo systemctl restart k6
```

- `yarn install` … package.json の依存関係をインストール（package.json 変更時のみ必要、毎回実行しても無害）
- `bin/rails assets:precompile` … 内部で `yarn build`（esbuild）・`yarn build:css`（Tailwind）を実行した後、**ダイジェスト（フィンガープリント）付きファイル名を生成して `public/assets` に配置する**（Propshaft本体の仕事）

**`yarn build && yarn build:css` だけでは不十分。** nginx の設定（[config/nginx/k6.conf](config/nginx/k6.conf)）は `/assets/` 配下をPumaを経由せず直接静的ファイルとして配信するため、Railsのビューヘルパーが参照するダイジェスト付きファイル名と実ファイルが一致している必要がある。`assets:precompile` を省略すると、古いダイジェストファイル・古いmanifestが残ったままになり、**コードは更新されても画面は旧レイアウトのまま**になる（2026-07-08に実際発生）。

`sudo systemctl restart k6` は毎回必須（本番は `config.cache_classes = true` でコード変更を自動リロードしないため、`git pull` だけでは反映されない）。

## 手動で `bin/rails` コマンドを叩くときの注意（RAILS_ENV）

サーバー上で `bin/rails` を単発で叩く（`assets:clobber`・`runner`・`console`など）ときは、**必ず `RAILS_ENV=production` を明示的に付ける**こと。

```bash
# NG: development環境として起動しようとして落ちる
bin/rails assets:clobber
# => Bundler::GemRequireError: ... cannot load such file -- debug/prelude

# OK
RAILS_ENV=production bin/rails assets:clobber
```

`RAILS_ENV` を指定しないと Rails はデフォルトの `development` として起動しようとする。`Gemfile` の `debug` gem は `group :development, :test` に入っており（[Gemfile](Gemfile)）、本番の `bundle install` ではこのグループを除外してインストールしているため、`development` として起動しようとした瞬間に `debug/prelude` が読み込めずに `Bundler::GemRequireError` で落ちる（2026-07-10に実際発生）。

「通常のデプロイ手順」内の `for kv in $(sudo systemctl show k6 --property=Environment ...)` を先にそのシェルで実行していれば `RAILS_ENV=production` も含めて読み込まれるはずだが、**新しくSSHし直した直後など、そのステップを飛ばしたシェルでは効いていない**。事故を避けるため、単発でRailsコマンドを叩くときは `for kv in ...` を実行済みかどうかによらず、常に `RAILS_ENV=production` を明示するのが安全。

## secret_key_base について

`config/master.key` は本番サーバーに置いていない。代わりに `k6.service` に直接 `Environment=SECRET_KEY_BASE=...` を埋め込んでいる（`sudo systemctl cat k6` で確認可能）。手動でRailsコマンドを叩く際は、上記の `for kv in ...` で同じ値をシェルに読み込む。

> シークレットをunitファイルに平文で書く方式はセキュリティ上あまり推奨されない（`systemctl show` や `/proc` から読める）。余裕があれば `EnvironmentFile=` + `.env`（パーミッション600）や `bin/rails credentials` + `master.key` への移行を検討。

## Node/yarn のセットアップ（初回 or `.node-version` 更新時のみ）

`.node-version` が更新された場合、サーバー側で該当バージョンの Node を入れ直す必要がある。

```bash
NODENV_ROOT=/opt/anyenv/envs/nodenv /opt/anyenv/envs/nodenv/bin/nodenv install <バージョン>
NODENV_ROOT=/opt/anyenv/envs/nodenv /opt/anyenv/envs/nodenv/versions/<バージョン>/bin/npm install -g yarn
NODENV_ROOT=/opt/anyenv/envs/nodenv /opt/anyenv/envs/nodenv/bin/nodenv rehash
```

Node 22以降は `corepack` が同梱されないことがあるため、`corepack enable` ではなく `npm install -g yarn` で直接入れる。

## サービス確認・操作

```bash
sudo systemctl status k6
sudo systemctl cat k6          # unit定義の確認（環境変数など）
sudo systemctl restart k6
sudo journalctl -u k6 -f       # ログをtail
```
