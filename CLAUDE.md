# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

K6 is a Rails 8 application combining user management/authentication with business functions ported from kobeengine (a legacy Rails app). Built with Hotwire (Turbo + Stimulus), Tailwind CSS + DaisyUI, HAML templates, and SQLite (via Solid Cache/Queue/Cable). Authentication is custom (Rails 8 generator, not Devise). UI is Japanese-localized.

### kobeengine 統合済みテーブル

adlists（顧客住所録）, keparts（KE部品）, orderparts（注文明細）, orders（注文台帳）, parts（部品台帳）, registries（国別為替）, stocks（在庫台帳）, stockbs（在庫台帳B）, tasks

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

### Deployment (Kamal)

```bash
bin/kamal deploy
bin/kamal console
bin/kamal logs -f
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
