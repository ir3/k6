# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

K2 is a Rails 8 user management and authentication starter built with Hotwire (Turbo + Stimulus), Tailwind CSS + DaisyUI, HAML templates, and SQLite (via Solid Cache/Queue/Cable). Authentication is custom (Rails 8 generator, not Devise). UI is Japanese-localized.

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

Three tables:

- **User** — `email_address` (normalized to lowercase/stripped), `password_digest` (`has_secure_password`), has_many :sessions, has_one :user_profile.
- **UserProfile** — `firstname`, `lastname` (max 20 chars), `state` (enum), `sign_in_at`, `sign_out_at`. 1:1 with User.
- **Session** — Tracks browser sessions. Belongs to User.

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

## Conventions

- Japanese locale (`config.time_zone = "Tokyo"`, `config.i18n.default_locale = :ja`). Locale files: `config/locales/ja.yml`, `config/locales/en.yml`.
- Use `Dry::Initializer` in ViewComponents instead of manual `initialize`.
- RuboCop config: `rubocop-rails-omakase` (`.rubocop.yml`).
