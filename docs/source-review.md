# AI Stupid Level watcher source review

This note records the public source contract the watcher currently follows.
The endpoints and scores are live and can change independently of this
repository.

## Verified source path

The deployed frontend is a Next.js app. Its public source requests:

- [cached dashboard](https://aistupidlevel.info/dashboard/cached?period=latest&sortBy=combined&analyticsPeriod=latest)
  for `data.modelScores` and related dashboard data;
- [score fallback](https://aistupidlevel.info/dashboard/scores?period=latest&sortBy=combined)
  when the cached response is unavailable;
- `reasoning` and `tooling` as separate `sortBy` values.

The frontend and backend source are public:

- [frontend request path](https://raw.githubusercontent.com/StudioPlatforms/aistupidmeter-web/main/app/HomeClient.tsx)
- [backend scoring path](https://raw.githubusercontent.com/StudioPlatforms/aistupidmeter-api/main/src/lib/model-scoring.ts)
- [synthetic-score implementation](https://raw.githubusercontent.com/StudioPlatforms/aistupidmeter-api/main/src/lib/synthetic-scores.ts)
- [benchmark fallback handling](https://raw.githubusercontent.com/StudioPlatforms/aistupidmeter-api/main/src/jobs/real-benchmarks.ts)
- [published methodology](https://aistupidlevel.info/methodology)

The observed row contract included `id`, `name`, `provider`, `vendor`,
`currentScore`, `score`, `trend`, `lastUpdated`, `status`, `isNew`, `isStale`,
`usesReasoningEffort`, `confidenceLower`, `confidenceUpper`, and
`standardError`. Values are dynamic; the watcher fetches and joins rows at
runtime rather than persisting a fixed ranking.

## Facts, local derivations, and limits

| Kind | Statement |
| --- | --- |
| Source fact | `combined` is computed by the backend from hourly, deep, and tooling scores with 50% / 25% / 25% weights. |
| Source fact | `reasoning` is the deep-benchmark view and `tooling` is the tool-calling view in the backend scoring code. |
| Source fact | The backend has a synthetic-score path and writes `[SYNTHETIC]` provenance into score notes. |
| Local derivation | The watcher orders rows by the returned combined score, takes the top 20, joins the three views by model id, and ranks the `provider: openai`/GPT-named subset. |
| Local presentation | `R` is a reasoning signal and `T` is a tool-use signal; they are not “smart reviewer” or “good worker” verdicts. |
| Limit | The dashboard row does not expose the per-score provenance note, so the menu cannot certify that each displayed score came from a real run. |
| Limit | This is one site's score system, not a vendor-neutral or official OpenAI/Anthropic/Google ranking. |
| Limit | Price-vs-score inversion is not computed because the public leaderboard does not provide current provider pricing. |

Use a score gap or a possible cheaper-model lead as a prompt for a bounded
review of task fit, confidence, freshness, and actual spend.

## Local service boundary

The foreground `swift run` path adds no third-party runtime, credentials,
browser automation, or provider configuration. The optional installer adds
only a user-level LaunchAgent and a local app bundle so the watcher can run at
login.
