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

# 入れるバージョンは `git pull` で更新された .ruby-version / .node-version の中身（cat で確認）。
# サーバー上でこの2ファイルを手で書き換えない（`rbenv local` / `nodenv local` も同じく書き換える）。
# 先に書き換えると、次の `git pull` が「local changes would be overwritten」で止まる
# （下の「`git pull` が `.node-version` のローカル変更で止まったとき」参照）。

# .ruby-versionが変わっていたら、rbenvで新バージョンを入れる
RBENV_ROOT=/opt/anyenv/envs/rbenv /opt/anyenv/envs/rbenv/bin/rbenv install <新バージョン>

# .node-versionが変わっていたら、nodenvで新バージョンを入れる
NODENV_ROOT=/opt/anyenv/envs/nodenv /opt/anyenv/envs/nodenv/bin/nodenv install <新バージョン>
NODENV_ROOT=/opt/anyenv/envs/nodenv /opt/anyenv/envs/nodenv/versions/<新バージョン>/bin/npm install -g yarn
NODENV_ROOT=/opt/anyenv/envs/nodenv /opt/anyenv/envs/nodenv/bin/nodenv rehash

bundle install

# Rails本番環境変数をこのシェルにも読み込む（systemdのk6.serviceと同じ値）
for kv in $(sudo systemctl show k6 --property=Environment | sed 's/^Environment=//'); do export "$kv"; done

# node/yarnをPATHに通す（↑でsystemd側のPATH（nodenv抜き）に上書きされるため、必ず"後"に実行）
export PATH="/opt/anyenv/envs/nodenv/shims:/opt/anyenv/envs/nodenv/bin:$PATH"
yarn -v   # 1.22.x系（nodenv shims）が出ることを確認。出なければ上のPATH設定を忘れている

# アセットビルド + フィンガープリント生成（cssやjsを変更した場合は必須）
# ↑の`for kv in ...`（SECRET_KEY_BASE等の読み込み）を済ませたシェルで実行すること。
# これを飛ばして`yarn install`から単独で実行すると、`assets:precompile`が
# `ArgumentError: Missing secret_key_base for 'production' environment`で落ちる
# （本番はmaster.keyを置かず、SECRET_KEY_BASEをk6.serviceの環境変数としてのみ
# 持っているため。2026-09-11に実際発生）。
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

### データは Mac で作った DB を丸ごとコピーする（個別の取り込みは ConoHa ではしない）

Access のデータは **Mac で SQLite3 に変換（`db/import/` のスクリプト）し、その DB を ConoHa へ丸ごとコピー**する。
ConoHa で `db/import/*.rb` を個別に流したり、テーブルだけ流し込んだりはしない。
在庫メンテナンスの `stock_settings`（標準在庫数・予測量・旧部品コード・補足情報・非表示）も、Mac で
`bin/rails runner db/import/import_stock_settings.rb` を実行して取り込み、コピーに含める。
コピーする DB はマイグレーション済み（`schema_migrations` が最新）なので、コピー後に ConoHa で `db:migrate` は要らない。

コピーはいつもの `scp` 1本。ただし **送る直前に WAL を本体に書き戻す**（下の1行目）。

```bash
# Mac 側
cd ~/k6
sqlite3 storage/development.sqlite3 "PRAGMA wal_checkpoint(TRUNCATE);"
scp storage/development.sqlite3 kobeengine@163.44.127.60:/var/www/k6/storage/production.sqlite3
```

```bash
# ConoHa 側: コピー後に反映する（「通常のデプロイ手順」と同じ）
sudo systemctl restart k6
```

- **`wal_checkpoint` を忘れない。** Mac の開発 DB は WAL モードで、直近の変更は `development.sqlite3-wal` に入っている。
  `scp` は本体ファイルだけを送るので、WAL に残った変更は ConoHa に行かない（開発サーバーを止めると本体に書き戻される）。
  `wal_checkpoint` の結果の先頭が `0` なら書き戻し完了。`1` なら開発サーバーが使用中なので、止めてからやり直す。
- 念のため: ConoHa の `storage/` に `production.sqlite3-wal` / `production.sqlite3-shm` が残っていると、古い WAL が
  新しい DB に適用されて壊れる恐れがある。コピーの前後で `k6` を止められるなら、止めてから WAL/SHM を消して差し替えると確実。
- **開発 DB の中身がそのまま本番に入る。** 動作確認用のアカウント（`preview-check@kobeengine.com`）も含まれる。
- ConoHa 側で増えたデータ（注文・在庫の更新・ユーザー）はコピーで上書きされる。コピー前に、Mac 側が最新であることを確認する。

### なぜ `assets:precompile` だけで完結するのか（`yarn build`を別途叩く必要がない理由）

Propshaftの`assets:precompile`タスクの中身は実はこれだけ（[propshaft](https://github.com/rails/propshaft) `lib/propshaft/railties/assets.rake`、2026-08-04時点でインストールされているv1.3.2で確認）。

```ruby
task precompile: :environment do
  Rails.application.assets.processor.process
end
```

Sprockets時代と違い、Propshaft自体はJS/CSSの変換（バンドル・トランスパイル）は一切しない。やっているのは「`config.assets.paths`（`app/assets/builds/`含む）にある出来上がったファイルにダイジェスト（内容ハッシュ）を付けて`public/assets/`へ配置し、`.manifest.json`に論理名→ダイジェスト付きファイル名の対応を書き出す」ことだけ。

実際のJS/CSSビルド（esbuild・Tailwind実行）は`jsbundling-rails`（v1.3.1）と`cssbundling-rails`（v1.4.3）が担当していて、この2つが`assets:precompile`タスクに前提条件としてフックしている（`jsbundling-rails`の`lib/tasks/jsbundling/build.rake`）。

```ruby
if Rake::Task.task_defined?("assets:precompile")
  Rake::Task["assets:precompile"].enhance(["javascript:build"])
end
```

（`cssbundling-rails`も同様に`css:build`をフック）。つまり`bin/rails assets:precompile`を叩くと、内部で

1. `yarn build`（`javascript:build`）
2. `yarn build:css`（`css:build`）
3. Propshaft本体のダイジェスト付与＋`public/assets/`配置＋manifest更新

の順で自動実行される。**だから`yarn build`/`yarn build:css`を手動で先に叩く必要はない**（叩いても実害はないが、`assets:precompile`が結局もう一度実行するだけの無駄な操作）。

`assets:precompile`自体を省略できないのは、上述の通りnginx（[config/nginx/k6.conf](config/nginx/k6.conf)）が`/assets/`をPumaを一切経由せず直接静的配信するため。nginxはRubyを実行しないので、開発環境のPropshaftのように「リクエスト時にその場でダイジェストを計算して返す」ということができず、`public/assets/`に実ファイルとして正しいダイジェスト付きファイルが物理的に存在している必要がある。

### `assets:clobber`は毎回やらなくていい（2026-08-04確認）

`assets:clobber`は`public/assets`（output_path）を丸ごと削除するだけ（propshaftの`processor.rb`: `FileUtils.rm_r(output_path)`）。一方`assets:precompile`は既存のダイジェスト付きファイルを消さず「まだ無いものだけ追加」する設計なので、`clobber`なしで毎回`precompile`するだけでも壊れない。

毎回`clobber`を挟むのはむしろ避けたほうがいい。デプロイ直前にサイトを開いていた人のブラウザには古いダイジェスト名（`application-旧hash.css`など）を参照したHTMLがキャッシュされていることがあり、`clobber`で物理ファイルごと消すと、その人はリロードするまで一時的にCSS/JSが崩れる。`precompile`だけなら新しいファイルが追加されるだけなので、この問題は起きない。

`public/assets`配下のファイル数が異常に増えてきた時のお掃除用途としてのみ使えば十分（2026-08-04時点で34件、特に問題なし）。

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

## `git pull` が `.node-version` のローカル変更で止まったとき

```
error: Your local changes to the following files would be overwritten by merge:
	.node-version
Please commit your changes or stash them before you merge.
```

**原因:** サーバー上で `.node-version` を先に手で書き換えた（または `/var/www/k6` 内で `nodenv local <ver>` を実行した）ため、
リポジトリ側の更新と衝突している（2026-10-08に実際発生。書き換えた値は今回の更新と同じ `26.11.0` だった）。
`.node-version` / `.ruby-version` はリポジトリの内容が正なので、サーバー側の変更は捨てて構わない。

```bash
cd /var/www/k6
git status --short           # まず何が変更されているか確認する
git diff .node-version       # 中身も確認（古い値 or 更新後と同じ値のはず）

git restore .node-version    # 対象ファイルだけを名前で指定して戻す（古いgitなら git checkout -- .node-version）
git pull
cat .node-version            # 新しいバージョンになっていればOK
```

**`git restore .` / `git checkout .` / `git reset --hard` / `git clean` / `git stash -u` は使わない。**
サーバー側には、リポジトリに無い手元の変更が他にも残っていることがあり、一括で捨てると消えてしまう。2026-10-08時点で
`git status --short` に出ていたのは次の3つで、`.node-version` 以外は触らずに `git pull` できた。

| ファイル | 状態 | 扱い |
|---------|------|------|
| `.node-version` | 変更あり | 上の手順で戻す |
| `config/nginx/k6.conf` | 変更あり（サーバー側だけの設定） | **捨てない**。リポジトリ側は最初のコミット以降変更が無く、`git pull` では触られない |
| `public/stylesheets` | 未追跡 | そのまま。リポジトリに追跡ファイルが無く、`git pull` に無関係 |

`.node-version` 以外の追跡ファイルが `git pull` を止めるようになった場合は、一括で捨てず、`git diff <ファイル>` で
中身を見てから、そのファイルだけを個別に判断する。

## secret_key_base について

`config/master.key` は本番サーバーに置いていない。代わりに `k6.service` に直接 `Environment=SECRET_KEY_BASE=...` を埋め込んでいる（`sudo systemctl cat k6` で確認可能）。手動でRailsコマンドを叩く際は、上記の `for kv in ...` で同じ値をシェルに読み込む。

> シークレットをunitファイルに平文で書く方式はセキュリティ上あまり推奨されない（`systemctl show` や `/proc` から読める）。余裕があれば `EnvironmentFile=` + `.env`（パーミッション600）や `bin/rails credentials` + `master.key` への移行を検討。

## Node/yarn のセットアップ（初回 or `.node-version` 更新時のみ）

> 「通常のデプロイ手順」に統合済み（2026-08-04）。以下は詳細の補足。

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
