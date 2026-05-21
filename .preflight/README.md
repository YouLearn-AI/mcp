# `.preflight/` — Preflight QA platform configuration

This directory wires this repo to **[Preflight](https://preflight.dev)**, an
LLM-driven QA harness for macOS desktop apps. When a Preflight workspace
has the GitHub App installed on this repo, any push to the default
branch (or any pull request) triggers a QA run against the produced
`.app`.

## Files

| File | What it does |
| --- | --- |
| [`preflight.yaml`](./preflight.yaml) | Declarative config — product name, runtime target (OS / version / arch), build entrypoint, build-time env vars, and macOS permissions the app needs. The Preflight harness clones this repo at the dispatched SHA, parses this file, and uses it to drive the run. |
| [`build.sh`](./build.sh) | Build entrypoint referenced from `preflight.yaml`'s `build.commands`. Runs cargo / swift / node-gyp / electron-vite / electron-builder in sequence and produces `dist/mac-arm64/VoiceOS.app`. Self-contained — no dependency on external scripts. |
| [`assets/`](./assets) | Build-time assets that aren't in the main source tree: app icon (`build/icon.icns`), menu-bar logos (`resources/build/*.png`), and macOS entitlements files. `build.sh` stages these into the workspace root if absent, so a fresh clone in CI has everything it needs. |

## What runs when

There are two ways a QA run gets triggered:

1. **GitHub App webhook (auto-trigger)** — when a push or pull request matches the rules configured in the Preflight dashboard, the App enqueues a run on its own. Defaults: any PR on this repo, and pushes to `main`. Edit the rules at https://preflight-web.prev.youlearn.ai/runs.
2. **GitHub Action (manual trigger)** — via `.github/workflows/preflight.yml`. Open the Actions tab → Preflight → "Run workflow" to fire on demand. Useful for ad-hoc reproductions, replaying a verdict against an older commit, or exposing Preflight as a step in other workflows.

Both produce identical runs in the dashboard (same `runs` row, same check-runs on PRs, same R2 report).

## Why these files exist in this repo (not on Preflight's side)

Preflight is **stateless** on the customer side: the harness has zero
knowledge of your app's build invariants. Everything build-related
(commands, env, assets) is owned by you and version-locked to your
SHAs. The platform contract is just "produce a `.app` under
`artifact_glob` after running `install` then `commands`."

## Local sanity check

```bash
bash .preflight/build.sh
ls dist/mac-arm64/VoiceOS.app
```

If that succeeds locally on an Apple Silicon Mac with `bun`, `rustup`,
Xcode CLT, and Node 20+, the same build will succeed inside Preflight's
QA VM. The QA VM image (`preflight-bake`) ships with all those tools
pre-installed.

## Editing this directory

Treat `preflight.yaml` as the contract — if you change `bundle_id`,
`runtime`, or `permissions`, the next QA run uses the new values
automatically. There's no separate "deploy" step on Preflight's side.

If you need credentials or other sensitive values at runtime (test
accounts, API tokens), do **not** add them to `build.env`. Contact
Preflight to provision them via the per-tenant secrets store, then
reference them by name in `preflight.yaml`.
