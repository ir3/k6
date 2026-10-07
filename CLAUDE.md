# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

**Docker は使用しない。** Dockerfile・docker-compose・Kamal は不要。デプロイは systemd + nginx の直接実行。手順・トラブルシューティングは [DEPLOY.md](DEPLOY.md) を参照。

K6 is a Rails 8 application combining user management/authentication with business functions ported from kobeengine (a legacy Rails app). Built with Hotwire (Turbo + Stimulus), Tailwind CSS + DaisyUI, HAML templates, and SQLite (via Solid Cache/Queue/Cable). Authentication is custom (Rails 8 generator, not Devise). UI is Japanese-localized.

### kobeengine 統合済みテーブル

adlists（顧客住所録）, keparts（KE部品）, orderparts（注文明細）, orders（注文台帳）, parts（部品台帳）, registries（国別為替）, stocks（在庫台帳）, stockbs（在庫台帳B）, tasks

k6 で追加: stock_settings（部品ごとの在庫設定。旧Accessの 標準在庫・必要在庫・在庫部品備考・在庫非表示 を統合。在庫メンテナンス画面で使用。`db/import/import_stock_settings.rb` で取り込み）

## Commands

### Development

```bash
bundle exec foreman start -f Procfile.dev   # Start all services (web + JS watch + CSS watch)
bin/rails server                            # Rails only (without asset watchers)
```

### Build Assets

```bash
yarn build           # Bundle JS with esbuild
yarn build:css       # Build Tailwind CSS
```

### Testing

```bash
bin/rails test                              # Unit and controller tests
bin/rails test:system                       # System (browser) tests
bin/rails db:test:prepare test test:system  # Full suite (CI equivalent)
bin/rails test test/models/user_test.rb     # Run a single test file
```

### Linting & Security

```bash
bin/rubocop -f github    # Lint (GitHub formatter)
bin/rubocop -A           # Auto-fix violations
bin/brakeman --no-pager  # Security scan
```

### Database

```bash
bin/rails db:migrate
bin/rails db:schema:load
bin/rails db:reset
```

### Deployment

Docker/Kamalは使わない。systemd + nginx（ConoHa本番）への直接デプロイ。手順は [DEPLOY.md](DEPLOY.md) 参照。

```bash
sudo systemctl status k6
sudo systemctl restart k6
sudo journalctl -u k6 -f
```

## Architecture

### Authentication

Custom session-based auth without Devise. Key files:

- `app/models/concerns/authentication.rb` — `Authentication` concern included in `ApplicationController`. Provides `require_authentication`, `resume_session`, `start_new_session_for`, `terminate_session`.
- `app/models/current.rb` — `ActiveSupport::CurrentAttributes` subclass storing `current_session` and `current_user` thread-locally.
- `app/models/session.rb` — Persisted session records (ip_address, user_agent, belongs_to :user).
- Sessions stored as signed cookies; `UserProfile` is auto-created on first login if missing.

### Authorization

Role-based via `UserProfile#state` enum: `offline(0)`, `online(1)`, `manager(2)`, `admin(9)`. Checks use `read_attribute_before_type_cast(:state) > 1` to compare raw integer values. Admin/manager can view all users; regular users only see themselves. Deletion is soft: sets state to `offline`.

### Models

認証系テーブル（k6 固有）:

- **User** — `email_address` (normalized to lowercase/stripped), `password_digest` (`has_secure_password`), has_many :sessions, has_one :user_profile.
- **UserProfile** — `firstname`, `lastname` (max 20 chars), `state` (enum), `sign_in_at`, `sign_out_at`. 1:1 with User.
- **Session** — Tracks browser sessions. Belongs to User.

業務テーブル（kobeengine より移植）:

- **Adlist** — 顧客住所録。`deleted_at` で論理削除。
- **Order** — 注文台帳。`belongs_to :adlists`。
- **Orderpart** — 注文明細。
- **Part** — 部品台帳（20,000件超）。
- **Kepart** — KE部品台帳。
- **Stock / Stockb** — 在庫台帳 / 在庫台帳B。
- **Registry** — 国別為替レート。

### Controllers

Rate-limited (10 req / 3 min) on `SessionsController` (login) and `SignUpsController` (registration). `UsersController` and `UserProfilesController` enforce role-based authorization inline.

### Views & Components

- All templates use **HAML** (no ERB).
- Reusable UI lives in `app/frontend/components/` as **ViewComponent** classes with `Dry::Initializer` for constructor arguments (base: `ApplicationViewComponent`).
- Stimulus controllers in `app/javascript/controllers/`. Notable: `row_link_controller.js` makes table rows clickable.

### Asset Pipeline

- **Propshaft** (asset pipeline) + **JSBundling** (esbuild) + **CSBundling** (Tailwind/DartSass).
- Built assets land in `app/assets/builds/`.
- SASS source in `app/assets/stylesheets/`.

### Background Jobs & Caching

Solid Queue, Solid Cache, and Solid Cable all run on SQLite (separate DB files in `storage/`). In production, Solid Queue runs inside the Puma process (`SOLID_QUEUE_IN_PUMA=true`).

## CI (GitHub Actions)

Three jobs on push/PR to main: **Scan Ruby** (Brakeman), **Lint** (RuboCop), **Test** (full suite with Chrome for system tests, screenshots uploaded on failure).

## Data Import

### Access DB → SQLite3

Windows の Access DB（.mdb）から業務データをインポートする仕組みが `db/import/` にある。

```bash
# ツール
brew install mdbtools

# テーブル一覧確認
mdb-tables db/access/ファイル名.mdb

# インポート実行
bin/rails runner db/import/import_adlists.rb
```

- `db/access/` は `.gitignore` 対象（機密データ）
- CP932 特殊文字（㈱, 﨑 など）の文字化けは `MOJIBAKE_MAP` で gsub 置換
- 詳細は `~/ob/Claude/access_to_sqlite3.md` 参照

#### 在庫メンテナンス用の `stock_settings`（2026-10-06 追加）

在庫メンテナンス画面（`/stock_maintenance`）の標準在庫数・予測量・旧部品コード・補足情報・非表示は、
`fsdb.mdb` の `標準在庫` `必要在庫` `在庫部品備考` `在庫非表示` を `stock_settings` テーブルに統合して持つ。
**Access → SQLite3 変換のとき、他のインポートと一緒にこれも実行すること**（本番へは Mac の DB を丸ごとコピーするので、
ここで取り込んでおかないと、本番の在庫メンテナンスの標準在庫・予測量・補足情報が空になる）。

```bash
bin/rails db:migrate                                        # 先に。stock_settings テーブルが無いと失敗する
bin/rails runner db/import/import_stock_settings.rb         # fsdb.mdb が必要。何度実行してもよい
```

- 部品番号ごとに1行にまとめて取り込む（同じ部品が複数あれば更新日が最新の行）。474件前後（2026-10-06時点）
- Access にある項目は、画面で更新した値を**上書きする**。運用開始後に再実行すると、k6 側で更新した標準在庫数などが戻る
- 本番への反映（DB の丸ごとコピー）は [DEPLOY.md](DEPLOY.md) の「データは Mac で作った DB を丸ごとコピーする」

#### 帳票出力履歴の `order_logs`（2026-10-07 追加）

旧Accessの `取引管理`（MNo, datelog, kubun）を `order_logs` に持つ。**追記専用の出力履歴**で、帳票を出力するたびに1行増える
（`OrdersController#report` が `XlsxReports::Registry` の `kubun` を見て `OrderLog.record` で書く）。
請求書・納品書・受領書は `kubun=4`（出荷案内）の日付を出荷日として読むので、履歴が無いと出荷日が出ない。
**Access → SQLite3 変換のとき、他のインポートと一緒にこれも実行すること**（本番へは DB を丸ごとコピーするため）。

```bash
bin/rails db:migrate                                   # 先に。order_logs テーブルが無いと失敗する
bin/rails runner db/import/import_order_logs.rb        # fsdb.mdb が必要。13.5万件前後。何度実行してもよい(IDで上書き)
```

- kubun: 1=部品見積依頼, 2=見積書, 3=受注メモ, 4=出荷案内書, 5=請求書A/B・同控・納品書B, 7=納品書A（旧ASPの値のまま）
- 運用開始後に再実行しても、Access に無い（k6 で追加した）行は消えない。Access と同じ ID の行だけ上書きされる

### .tab ファイルからのインポート（旧来方式）

`db/seeds/` に各テーブル用スクリプトあり。`bin/rails runner db/seeds/xxx.rb` で実行。

## Gems（主要追加分）

| Gem | 用途 |
|-----|------|
| `kaminari` | ページネーション |
| `caxlsx_rails` | Excel（.xlsx）出力（adlists） |
| `csv` | Ruby 4.0 で標準から外れたため明示追加 |
| `haml-rails` | HAML テンプレート |
| `view_component` | ViewComponent |
| `dry-initializer` | ViewComponent のコンストラクタ |

## Conventions

- Japanese locale (`config.time_zone = "Tokyo"`, `config.i18n.default_locale = :ja`). Locale files: `config/locales/ja.yml`, `config/locales/en.yml`.
- Use `Dry::Initializer` in ViewComponents instead of manual `initialize`.
- RuboCop config: `rubocop-rails-omakase` (`.rubocop.yml`).
- 業務テーブルは `ActiveRecord::Base` を直接継承（kobeengine 由来）。
- テーブルのスタイルは `center-table radius-table` クラス（`k.css` で定義、枠線 1px）。
