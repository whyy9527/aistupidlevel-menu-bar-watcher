# AI Stupid Level macOS menu-bar watcher

A native, dependency-free macOS menu-bar watcher for the public [AI Stupid
Level leaderboard](https://aistupidlevel.info/?mode=leaderboard&period=latest&sortBy=combined).
It keeps the combined top 20, value top 20, GPT cluster, Claude cluster, and a
compact Claude-vs-GPT comparison one click away. A persistent dynamic-island-
style pill at the top of the screen shows current GPT/Claude intelligence
inversions without opening the menu.

[![CI](https://github.com/whyy9527/aistupidlevel-menu-bar-watcher/actions/workflows/ci.yml/badge.svg)](https://github.com/whyy9527/aistupidlevel-menu-bar-watcher/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Why watch this ranking?

The useful signal is comparative rather than absolute:

- see the gap between models on the same published scoring system;
- see a same-family `USE` pick when a lower-cost model remains near the score
  of a more expensive peer while materially improving price/performance;
- compare a model's `reasoning` and `tooling` lenses instead of treating one
  combined number as a complete model verdict.

The watcher includes a price/performance view. It uses the upstream project's
[published model-price mapping](https://github.com/StudioPlatforms/aistupidmeter-web/blob/main/lib/model-pricing.ts): standard first-party list prices in USD per 1M tokens. The price estimate is `40% input + 60% output`; value is the current combined score divided by that estimate. Models without a specific mapping are excluded rather than assigned a guessed price.

This is a source-monitoring aid, not an automated model selector. A score gap
is a reason to inspect the task mix, confidence interval, freshness, and real
cost before changing a production model.

## Cluster recommendation

The GPT and Claude clusters use the same deterministic gate. A `USE` candidate
must be present in both visible lists: combined `TOP 20` and `TOP VALUE` top
20. It must first be within `max(3 points, 7%)` of its cluster's `TOP 20`
leader by the published combined point score; confidence-range overlap does not
override that gate, so a low-score bargain cannot displace the intelligence
frontier. It is then compared with the
highest-scoring more expensive same-cluster peer from `TOP 20`; it must simply
be cheaper. The best-ranked `TOP VALUE` candidate is shown once per cluster
only when it has a strict point-score lead over that peer. It is shown as an
`⚡︎` intelligence inversion; there is no near-score `VALUE` substitute. This
makes Terra-over-Sol surface while a lower-score Luna-over-GPT-5.5 pairing
cannot.

## Run

Requires macOS 13 or later and the system Swift toolchain:

```sh
git clone https://github.com/whyy9527/aistupidlevel-menu-bar-watcher.git
cd aistupidlevel-menu-bar-watcher
swift run AIStupidLevelWatcher
```

The process lives in the menu bar while it runs. The command above is a
foreground run and does not install a login item or a LaunchAgent. Use `Quit`
in the menu or stop the process from the terminal.

## Keep it running on macOS login

To install the watcher as a user-level macOS service:

```sh
./scripts/install-macos-service.sh
```

The installer builds a release app under
`~/Applications/AIStupidLevelWatcher.app`, registers
`com.whyy9527.aistupidlevel.menu-bar-watcher` as a `LaunchAgent`, and starts it
immediately. It runs at login and restarts after an unexpected crash. A normal
`Quit` from the menu exits cleanly and stays stopped until you launch it again.
No administrator password or Accessibility/Screen Recording permission is
required. Service logs are written to
`~/Library/Logs/AIStupidLevelWatcher/`.

To stop and remove the installed service:

```sh
./scripts/uninstall-macos-service.sh
```

## Data path

The page currently uses these public JSON views:

- `GET /dashboard/cached?period=latest&sortBy=combined&analyticsPeriod=latest`
- `GET /dashboard/cached?period=latest&sortBy=reasoning&analyticsPeriod=latest`
- `GET /dashboard/cached?period=latest&sortBy=tooling&analyticsPeriod=latest`

If a cached request fails, the watcher follows the page's public fallback to
`/dashboard/scores?period=latest&sortBy=<view>`. The app only replaces its
snapshot after all three views decode successfully. A failed refresh keeps the
last successful snapshot and shows the error in the menu.

The default refresh interval is 30 minutes, with a manual `Refresh` action.
The source says its scores update every four hours, so this is a display
watcher, not a claim of minute-level benchmark freshness.

## Evidence boundary

The source repository calls `combined` a 50% hourly + 25% deep + 25% tooling
weighted score. Its backend also contains a synthetic-score generator that
marks generated rows with `[SYNTHETIC]`; the public dashboard row does not carry
that provenance note. Therefore this app watches the site's published signal,
not an independently audited benchmark. It does not claim that a high `R`
score proves review quality or that a high `T` score proves production task
reliability.

## Reading the menu

- `V`: value score: `combined ÷ (0.4 × input price + 0.6 × output price)`.
  It is displayed as benchmark points per estimated USD and is an estimate, not
  a cost guarantee. Cached-token discounts, long-context tiers, regional
  pricing, provider discounts, and task-specific input/output mix can change it.
- `TOP 20`: source `combined` ordering.
- `TOP VALUE`: current price/performance ordering.
- `GPT CLUSTER` and `CLAUDE CLUSTER`: provider-family rows plus their optional
  same-family `USE` pick.
- Persistent island: current `⚡︎` intelligence inversions. It remains visible
  with a loading or no-inversion state, and each inversion can be clicked to
  open the recommended model page.
- `CLAUDE VS GPT`: each cluster's score leader and value pick.
- `C`: source `combined` view, used for the combined top-20 ordering.
- `R`: source `reasoning` view, a deep-reasoning signal.
- `T`: source `tooling` view, a tool-calling signal.
- GPT/Claude rows are selected by their source provider (`openai`/`anthropic`)
  or matching model-name prefix, including rows outside the combined top 20.

The `R` and `T` labels are deliberately signals, not verdicts. They do not
prove that a model is a good safety reviewer, a generally intelligent system,
or a reliable production worker. They are a compact way to decide what to
inspect next, with the source's methodology and confidence metadata remaining
the evidence boundary.

## Verification

```sh
swift build
./verify-models.sh
curl -fsS 'https://aistupidlevel.info/dashboard/cached?period=latest&sortBy=combined&analyticsPeriod=latest'
```

No third-party package, account, API key, browser state, model weight, or
benchmark execution is part of this experiment. The optional service installer
only adds a local user LaunchAgent and a local app bundle.

Primary source review: [`docs/source-review.md`](docs/source-review.md).
