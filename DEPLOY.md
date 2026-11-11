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
sqlite3 storage/development.sqlite3 "DELETE FROM sessions;"   # Mac のログイン履歴を本番へ持ち込まない（Mac では再ログインになる）
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
- **開発 DB の中身がそのまま本番に入る。** そのため、動作確認用のアカウント（`preview-check@kobeengine.com`）は開発 DB に入れない。
  ブラウザでの動作確認は、開発 DB のコピー `storage/preview.sqlite3` を使う（`bin/prepare_preview`。`.claude/launch.json` の `rails-preview` が `K6_DB=storage/preview.sqlite3` で起動）。
  送る前に `sqlite3 storage/development.sqlite3 "select email_address from users"` で、見覚えのないアカウントが無いか見ておくと確実。
- **`sessions` を空にしてから送る。** ログインの記録（IP・ブラウザ・ユーザーの対応）を本番へ持ち込まない。
  本番とは `secret_key_base` が違うので、Mac のクッキーは本番では使えない。それでも、記録そのものを渡さないほうがよい。
  Mac では、次にアクセスしたときに再ログインになる。
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

## Ubuntu のアップグレード（24.04 LTS → 26.04 LTS）

> 2026-11-10 時点の調査をもとにしたチェックリスト（**未実施**）。実施したら、実績（所要時間・詰まった点）をここに追記する。
> 「(推測)」は公式情報ではなく、この構成からの見立て。「(未確認)」は画面や実機で確かめていない項目。

### 判断の前提

- **急がない。** 24.04 LTS の標準サポートは 2029 年 4 月まで。
- 24.04 → 26.04.1 のアップグレード経路は 2026-09-30 に解禁済み（`-d` オプション不要）。
  `/etc/update-manager/release-upgrades` が `Prompt=lts` なら、`sudo do-release-upgrade` で上がる。
- k6 は**止まる**（30〜60 分見込み）。深夜か休日に、利用者へ周知してから行う。
- 作業中は**本番データを更新しない**。Mac からの DB コピーもしない（ロールバックで失うデータを増やさないため）。
- 代案: 26.04 の新しいサーバーを立てて組み直し、確認してから切り替える方法もある。やり直しは利くが、nginx・HTTPS・systemd・rbenv などをすべて作り直す手間がかかる。

### 事前チェックリスト

- [ ] **ConoHa でスナップショット（イメージ保存）を取る**（コントロールパネルのメニュー名は未確認）
- [ ] 設定とデータを Mac に退避する

  ```bash
  # ConoHa 側: root 所有のファイルをまとめる
  sudo tar czf /tmp/k6-etc-backup.tgz /etc/letsencrypt /etc/nginx /etc/systemd/system/k6.service /etc/ufw
  cp /var/www/k6/storage/production.sqlite3 /tmp/production.sqlite3.backup

  # Mac 側
  mkdir -p ~/backup/conoha-20261110 && cd ~/backup/conoha-20261110
  scp conoha:/tmp/k6-etc-backup.tgz conoha:/tmp/production.sqlite3.backup .
  ```
  （`k6.service` には `SECRET_KEY_BASE` が入っている。退避したファイルの置き場に注意）
- [ ] 24.04 を最新にして再起動する: `sudo apt update && sudo apt full-upgrade && sudo reboot`
- [ ] 追加リポジトリ（PPA など）が無いか確認し、あれば外す（アップグレード失敗の典型的な原因）: `ls /etc/apt/sources.list.d/`
- [ ] ディスクの空き（数 GB 以上）: `df -h / /boot`
- [ ] 今のバージョンを控える（上がったあとの比較用）

  ```bash
  lsb_release -d; uname -r
  # k6.service は rbenv のシム経由（ExecStart=/opt/anyenv/envs/rbenv/shims/bundle）で動く。
  # Ruby の版は、WorkingDirectory(/var/www/k6)の .ruby-version で決まる
  cd /var/www/k6 && cat .ruby-version
  /opt/anyenv/envs/rbenv/shims/ruby -v                  # サービスと同じ解決。.ruby-version と同じ版になること
  sudo systemctl cat k6 | grep -E 'ExecStart|RBENV'     # ExecStart がシム経由か。RBENV_VERSION が固定されていないか
  nginx -v; openssl version; sqlite3 --version
  sudo systemctl status k6 --no-pager | head -5
  sudo certbot certificates
  sudo ufw status
  ```
- [ ] **予行演習（推奨）**: スナップショットから複製サーバーを作り、そちらで先に上げて k6 が動くか確認する（ConoHa での複製手順は未確認）
- [ ] 同じサーバーに他のアプリ（k5 など。`/var/www/k5`、`k5.service`）が残っていれば、それも確認対象にする
- [ ] 経路の確認: `sudo do-release-upgrade -c` で 26.04.1 が出ること
- [ ] **ファイアウォールは 2 層**（ConoHa のセキュリティグループ **と** サーバー内の ufw。片方だけでは通らない）。
      SSH が切れたときの予備として、`do-release-upgrade` が使う **1022/tcp を両方で一時的に開ける**
- [ ] ConoHa のコンソール（VNC）から入れることを確認する（SSH が切れたときの最後の手段）

### 当日の手順

```bash
sudo do-release-upgrade
```

- SSH 経由だと、自動で `screen` の中で動き、予備の sshd がポート 1022 で起動する。
- 設定ファイルの扱いを聞かれたら、`/etc/nginx/nginx.conf`・`/etc/ssh/sshd_config` などは**「今のものを残す」**を選び、あとで差分を見る。
  （k6 の `/etc/nginx/conf.d/k6.conf` はパッケージの管理外なので、上書きされない）
- 「サービスを再起動してよいか」は Yes。「不要なパッケージを削除するか」は、動作確認が済むまで No。
- 終わったら再起動する。**別のターミナルから新しく SSH で入れること**を、すぐ確認する。

### アップグレード後のチェックリスト

- [ ] OS が上がっている: `lsb_release -d`（26.04 LTS）
- [ ] 一時的に開けた **1022/tcp を、ConoHa のセキュリティグループと ufw の両方で閉じる**。ufw に 22・80・443 が残っている: `sudo ufw status`
- [ ] **Ruby と gem(推測)**: rbenv でビルドした Ruby とネイティブ拡張の gem（sqlite3・puma など）が、OpenSSL（3.5.6 に更新）などのシステムライブラリを使っているため、動かなくなる可能性がある

  ```bash
  # k6.service が使う Ruby（rbenv のシムが .ruby-version から決める版）の実体
  RB=/opt/anyenv/envs/rbenv/versions/$(cat /var/www/k6/.ruby-version)/bin
  /opt/anyenv/envs/rbenv/shims/ruby -v    # 「version is not installed」と出たら、下の入れ直しへ
  $RB/ruby -v
  $RB/ruby -ropenssl -e 'puts OpenSSL::OPENSSL_LIBRARY_VERSION'
  cd /var/www/k6 && RAILS_ENV=production $RB/bundle exec rails -v   # RAILS_ENV を忘れない（上の注意）
  ```
  動かなければ、ビルドに必要なパッケージを入れて Ruby を入れ直し、gem を作り直す:
  ```bash
  sudo apt install -y build-essential libssl-dev libyaml-dev libffi-dev zlib1g-dev libreadline-dev libsqlite3-dev
  RBENV_ROOT=/opt/anyenv/envs/rbenv /opt/anyenv/envs/rbenv/bin/rbenv install -f $(cat /var/www/k6/.ruby-version)
  cd /var/www/k6 && $RB/bundle pristine
  ```
  - `k6.service` の `ExecStart` は `/opt/anyenv/envs/rbenv/shims/bundle`（シム）なので、Ruby の版は `.ruby-version` に従う。
    unit の書き換えは要らない（版を固定したパスを書いた古いメモもあるので注意。2026-11-10 に実機で確認）。
  - 版が固定されていないか: `sudo systemctl cat k6` に `RBENV_VERSION` や `versions/x.y.z` が出ていたら、`.ruby-version` に従わないので直す。
- [ ] Node/yarn(推測): `node -v`、`yarn -v`（PATH は「通常のデプロイ手順」と同じ）。Node は単体のバイナリなので、通常は問題ない
- [ ] k6: `sudo systemctl status k6`、`sudo journalctl -u k6 -n 50`
- [ ] nginx: `sudo nginx -t`、`sudo systemctl status nginx`
- [ ] **HTTPS**: `sudo certbot certificates`、`sudo certbot renew --dry-run`、`sudo systemctl status certbot.timer`
- [ ] **sudo が `sudo-rs` に変わった**: `sudo -V`、`sudo -l`。`/etc/sudoers` と `/etc/sudoers.d/` に独自設定があれば、`sudo-rs` が対応しているか確認する。
      旧来の sudo は `sudo.ws` という名前で残る
- [ ] **coreutils の一部が Rust 版になった**（`cp` `mv` `rm` は GNU のまま）。「通常のデプロイ手順」を一通りリハーサルして、スクリプトの挙動に差がないか確認する
  （`git pull` → `for kv in $(sudo systemctl show k6 ...)` → `assets:precompile` → `restart`）
- [ ] **SSH の鍵**: OpenSSH 10.2 で DSA 鍵が使えなくなった。`ssh conoha` で入れること（ed25519・RSA なら問題ない）
- [ ] アプリの動作: ログイン、取引台帳、注文部品詳細、在庫メンテナンス、帳票（Excel）の出力
- [ ] 時刻: `timedatectl`（既存の環境は `systemd-timesyncd` のまま。`chrony` への切り替えは新規インストールだけ）
- [ ] スナップショットと退避ファイルは、1〜2 週間は残してから消す
- [ ] この節に実績を追記する

### ロールバック

問題が出て直せないときは、**ConoHa のスナップショットから復元**する。スナップショット以降の本番データ（作業中に更新したもの）は戻らないので、
作業中は本番データを更新しない（上の「判断の前提」）。復元後は、サービスと HTTPS の状態を確認する。

### 参考（公式）

- [Upgrades from Ubuntu 24.04 LTS to Ubuntu 26.04.1 LTS now enabled](https://discourse.ubuntu.com/t/upgrades-from-ubuntu-24-04-lts-to-ubuntu-26-04-1-lts-now-enabled/88502)
- [Ubuntu 26.04 LTS summary - Ubuntu release notes](https://documentation.ubuntu.com/release-notes/26.04/summary-for-lts-users/)
- [What's new in security for Ubuntu 26.04 LTS?](https://ubuntu.com/blog/ubuntu-26-04-lts-security-updates)
- [Rust-coreutils 0.10 now available for Ubuntu 26.04 LTS](https://discourse.ubuntu.com/t/rust-coreutils-0-10-now-available-for-ubuntu-26-04-lts/88120)
