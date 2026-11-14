#!/usr/bin/env bash
# Prepare a fresh Linux container (Superconductor, Codespaces, CI-like boxes) to
# run this repo's tooling. Safe to re-run; each step is skipped when already done.
#
#   .agents/skills/bjc-env-setup/scripts/setup.sh            # Ruby + gems (fast specs, rubocop, build tools)
#   .agents/skills/bjc-env-setup/scripts/setup.sh --browser  # ...plus headless Chrome for the browser specs
#
# Best run as a Superconductor *build command*, so the result is baked into the
# project snapshot and the downloads happen before network rules apply.
set -euo pipefail

cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
want_browser=false
[[ "${1:-}" == "--browser" ]] && want_browser=true

step() { printf '\n==> %s\n' "$*"; }
as_root() { if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi; }

# Several gems (bigdecimal, json, prism for rubocop) build native extensions.
if ! command -v gcc >/dev/null || ! command -v make >/dev/null; then
  step "Installing a C toolchain"
  as_root apt-get update -qq
  as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq build-essential libyaml-dev
fi

# The Ruby version is pinned in .tool-versions; mise installs a precompiled build.
if ! command -v mise >/dev/null; then
  echo "mise is not installed. Install Ruby $(awk '/^ruby/ {print $2}' .tool-versions) another way, then re-run." >&2
  exit 1
fi
if ! mise exec -- ruby -v >/dev/null 2>&1; then
  step "Installing Ruby from .tool-versions"
  mise install ruby
fi

step "Installing gems"
mise exec -- bundle check >/dev/null 2>&1 || mise exec -- bundle install

if $want_browser; then
  step "Installing Chromium and its system libraries"
  npx -y playwright@latest install --with-deps chromium

  # The specs drive Chrome through Selenium, which fetches its own Chrome and
  # chromedriver pair on first use. Fetch them now so that never happens mid-task.
  step "Caching Chrome + chromedriver for Selenium"
  manager="$(mise exec -- gem contents selenium-webdriver | grep 'bin/linux/selenium-manager$')"
  "$manager" --browser chrome >/dev/null
fi

step "Ready"
mise exec -- ruby -v
echo "If 'ruby' or 'bundle' is not found on your PATH, prefix commands with 'mise exec --'."
