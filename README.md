# react-bundle-audit

Paste a `Gemfile.lock` into a text field and see which gems have known vulnerabilities, using [bundler-audit](https://github.com/rubysec/bundler-audit) and the Ruby Advisory Database.

This is a *learning* project: a Rails API plus a separate React frontend, in one repo.

```
api/   Rails 8.1 API-only app (Postgres, Minitest, bundler-audit)
web/   Vite + React + TypeScript frontend
```

Tool versions are pinned in `.tool-versions` (Ruby 4.0.7, Node 26.7.0).

## What it does

1. The frontend sends the pasted text to `POST /api/audits` as JSON: `{"lockfile": "..."}`.
2. The API normalizes and validates the text, since bundler-audit needs a clean `Gemfile.lock` on disk:
   - strips a BOM, converts CRLF to LF, trims surrounding whitespace, ends with one newline
   - rejects empty input, text with no gems under `GEM` specs, merge-conflict markers, and anything over 1 MB (422 with readable messages)
3. It pulls the latest advisories (the equivalent of `bundle-audit check --update`) on every request.
   - If the pull fails but a stored copy exists, it scans the stored copy and returns a warning: "Unable to fetch the latest advisories; falling back to stored database last updated ...".
   - If the pull fails and nothing is stored, it returns 503.
4. It writes the normalized text to a temp directory as `Gemfile.lock` and runs `Bundler::Audit::Scanner` on it.
5. It stores the run (lockfile, findings, warnings, advisory database date) as an `Audit` record and returns the findings.

The advisory database lives in `~/.local/share/ruby-advisory-db` (override with `BUNDLER_AUDIT_DB`). The first request clones it, so that one is slower.

### API

| Method | Path              | Description                                   |
| ------ | ----------------- | --------------------------------------------- |
| POST   | `/api/audits`     | Run an audit. Body: `{"lockfile": "<text>"}`  |
| GET    | `/api/audits/:id` | Fetch a stored audit (the lockfile is omitted) |

Response (201 on create):

```json
{
  "id": 1,
  "results": [
    {
      "type": "unpatched_gem",
      "gem": { "name": "nokogiri", "version": "1.5.0" },
      "advisory": { "id": "CVE-2012-6685", "cve": "CVE-2012-6685", "ghsa": null, "url": "...", "title": "...", "description": "...", "criticality": "high", "date": "2013-01-01", "patched_versions": ["..."], "unaffected_versions": [] }
    },
    { "type": "insecure_source", "source": "http://rubygems.org/" }
  ],
  "warnings": [],
  "advisory_db_updated_at": "2026-10-21T...",
  "created_at": "..."
}
```

### Code map

- `api/app/models/audit.rb`: normalization and validation
- `api/app/services/advisory_database.rb`: update-or-fall-back logic for the advisory database
- `api/app/services/audit_runner.rb`: temp file, scan, serialize findings
- `api/app/controllers/audits_controller.rb`: the two endpoints
- `web/src/api.ts`: typed API client
- `web/src/App.tsx`: the UI

## How the project was initialized

Run from the repo root.

```bash
# Tool versions
printf 'ruby 4.0.7\nnodejs 26.7.0\n' > .tool-versions

# Rails API app: Postgres, Minitest, no Solid*/Kamal/Thruster/rubocop/mailer/storage
rails new api --api --database=postgresql --skip-git --skip-kamal --skip-thruster \
  --skip-solid --skip-rubocop --skip-brakeman --skip-ci --skip-action-mailer \
  --skip-action-mailbox --skip-action-text --skip-active-storage --skip-jbuilder

# React + TypeScript frontend
npm create vite@latest web -- --template react-ts
cd web && npm install
```

Gemfile changes after generation:

- `bundler-audit` moved out of the dev/test group (the app uses it at runtime) and set to `require: "bundler/audit/scanner"`
- added `standard`, `standard-rails` (dev/test) and `shoulda-context`, `shoulda-matchers`, `minitest-mock` (test). Minitest 6 split `minitest/mock` into its own gem.
- `.standard.yml` enables the `standard-rails` plugin

The Vite dev server proxies `/api` to Rails (`web/vite.config.ts`), so there is no CORS setup.

## Setup

```bash
asdf install            # Ruby 4.0.7, Node 26.7.0 (if not already installed)

cd api
bundle install
bin/rails db:create db:migrate

cd ../web
npm install
```

Postgres must be running locally. The default config connects over the local socket as your user.

## Running

Two terminals:

```bash
# API on http://localhost:3000
cd api && bin/rails server

# Frontend on http://localhost:5173
cd web && npm run dev
```

Open http://localhost:5173, paste a `Gemfile.lock`, and click "Run audit".

Quick API check without the UI:

```bash
curl -s localhost:3000/api/audits \
  -H 'Content-Type: application/json' \
  -d "$(jq -Rs '{lockfile: .}' < path/to/Gemfile.lock)"
```

## Tests and lint

```bash
cd api
bin/rails test        # Minitest + shoulda-context; the advisory fetch is stubbed per test
bundle exec standardrb

cd ../web
npm run lint          # oxlint
npm run build         # also type-checks (tsc -b)
```

The tests stub `AdvisoryDatabase.refresh` (via `stub_advisory_refresh!`) so they do not hit the network, but the scan itself reads the real advisory database on disk. Run a real audit once first so the database exists.
