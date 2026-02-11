## Codebase Patterns
- Root `bundle exec rake spec` runs all 6 gems' test suites sequentially
- Root `bundle exec rubocop` scans 121 Ruby files (excludes gemspecs, vendor, tmp)
- Rubocop does not scan `.github/` directory by default (only Ruby files)
- Use `ruby/setup-ruby@v1` with `bundler-cache: true` for efficient CI setup
- Ruby versions to test: 3.1, 3.2, 3.3, 3.4 (target version in .rubocop.yml is 3.1)

---

## 2026-02-11 - US-001
- **What was implemented**: Core CI workflow for running tests on push/PR
- **Files changed**: `.github/workflows/ci.yml` (new file)
- **Details**: Created GitHub Actions CI workflow that triggers on push to `main` and PRs targeting `main`. Uses `actions/checkout@v4` and `ruby/setup-ruby@v1` with bundler caching. Runs `bundle exec rake spec` across Ruby version matrix (3.1, 3.2, 3.3, 3.4).
- **Learnings for future iterations:**
  - The workflow file also covers US-002 (Ruby version matrix) since matrix strategy was included from the start
  - `bundler-cache: true` in `ruby/setup-ruby` handles caching automatically - no need for separate cache actions
  - `fail-fast: false` on matrix ensures all versions are tested even if one fails

---

## 2026-02-11 - US-002
- **What was implemented**: Ruby version matrix was already implemented as part of US-001
- **Files changed**: `.chief/prds/ci-cd/prd.json` (marked passes: true)
- **Details**: The CI workflow created in US-001 already included the full matrix strategy with Ruby 3.1, 3.2, 3.3, 3.4 and `fail-fast: false`. All acceptance criteria were already met.
- **Learnings for future iterations:**
  - When implementing foundational stories (US-001), subsequent related stories may already be satisfied
  - Always check what's already in place before implementing

---
