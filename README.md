# AI Stupid Level macOS menu-bar watcher

A native, dependency-free macOS menu-bar watcher for the public [AI Stupid
Level leaderboard](https://aistupidlevel.info/?mode=leaderboard&period=latest&sortBy=combined).
It keeps the current combined top 20 and the GPT/OpenAI-family ranking one
click away.

## Why watch this ranking?

The useful signal is comparative rather than absolute:

- see the gap between models on the same published scoring system;
- see whether a model that is cheaper in your own price sheet is scoring above
  a more expensive model — an “intelligence inversion” worth investigating;
- compare a model's `reasoning` and `tooling` lenses instead of treating one
  combined number as a complete model verdict.

The watcher does not fetch or guess provider prices. The public leaderboard
does not publish price metadata, so price-vs-score inversion remains an
explicit comparison step rather than a fabricated in-app ranking.

This is a source-monitoring aid, not an automated model selector. A score gap
is a reason to inspect the task mix, confidence interval, freshness, and real
cost before changing a production model.

## Run

Requires macOS 13 or later and the system Swift toolchain:

```sh
git clone https://github.com/whyy9527/aistupidlevel-menu-bar-watcher.git
cd aistupidlevel-menu-bar-watcher
swift run AIStupidLevelWatcher
```

The process lives in the menu bar while it runs. It does not install a login
item or a LaunchAgent. Use `Quit` in the menu or stop the process from the
terminal.

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

- `C`: source `combined` view, used for the top-20 ordering.
- `R`: source `reasoning` view, a deep-reasoning signal.
- `T`: source `tooling` view, a tool-calling signal.
- `GPT / OpenAI family`: rows whose source provider is `openai`, plus GPT-named
  rows, including rows outside the combined top 20.

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
benchmark execution is part of this experiment.

Primary source review: [`docs/source-review.md`](docs/source-review.md).
