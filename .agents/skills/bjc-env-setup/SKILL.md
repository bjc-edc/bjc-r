---
name: bjc-env-setup
description: Get Ruby, Bundler, and headless Chrome working in a fresh container so the bjc-r specs, rubocop, and build tools can run. Use when `ruby` or `bundle` is not found, a gem fails to build, the browser specs cannot start Chrome, or a download returns a network-policy 403.
---

# Setting up the bjc-r toolchain

Fresh cloud containers for this project have Node and Python but **no Ruby, no C
compiler, and no Chrome**. Do not skip verification or hand-build a substitute test
harness because of that. Run the setup script first; it takes about a minute.

```sh
.agents/skills/bjc-env-setup/scripts/setup.sh            # Ruby + gems
.agents/skills/bjc-env-setup/scripts/setup.sh --browser  # also Chrome for browser specs
```

The script is safe to re-run. It installs a C toolchain (several gems build native
extensions), the Ruby version pinned in `.tool-versions` through `mise`, the gems,
Chromium's system libraries, and the Chrome + chromedriver pair Selenium uses.

Check that it worked:

```sh
bundle exec rspec utilities/specs/build_tools_spec.rb utilities/specs/summary_pages_spec.rb
bundle exec rspec utilities/specs/self_check_feedback_spec.rb   # needs --browser
```

## Which specs need what

| Needs only Ruby | Needs Chrome too |
| --- | --- |
| `build_tools_spec.rb`, `summary_pages_spec.rb`, `rubocop`, `rebuild-all.rb` | `accessibility_spec.rb`, `dynamic_navigation_spec.rb`, `content_anchors_spec.rb`, `self_check_feedback_spec.rb` |

The specs start their own web server; you do not need `./run-server` running.

## When a download is blocked

A response of `403 … forbidden by network policy` means the project's network rules
block that host. Retrying will not help.

1. Stop, and tell the user which host was blocked and what it was needed for.
2. Ask them to allow it in the project's network settings, or to tell you to proceed
   without it.
3. Carry on with every part of the task that does not need that host.

Hosts the toolchain needs: `rubygems.org`, `github.com` (precompiled Ruby),
`cdn.playwright.dev`, `googlechromelabs.github.io`, and `storage.googleapis.com`
(the last two are how Selenium finds and downloads Chrome).

A `403` from a site you are checking for link rot tells you nothing about whether
the link is dead. Say that it could not be checked rather than guessing.

## Making this permanent in Superconductor

Add the script as a **build command** in Project Settings → Development Environment
so it is baked into the snapshot. Build commands run before network rules apply, so
the downloads succeed even with a strict policy:

```sh
cd /workspace/bjc-r && .agents/skills/bjc-env-setup/scripts/setup.sh --browser
```

## If you still cannot run something

Say so in your final message, name the command and the error, and list what was left
unverified so the reviewer knows to rely on CI for it. Do not describe unverified
work as verified.
