---
name: pairwise-price-dominance
description: |
  Build or audit same-family "smarter and cheaper" model recommendations and
  智能倒挂 rules. Use when TOP VALUE/value rank is being used to choose a
  GPT/Claude recommendation, when a more expensive model is shown over a
  cheaper peer, or when an app must explain per-model prices and savings.
---

# Pairwise Price Dominance

## Failure Mechanism

A global value rank is `score / modelCost`; it does not establish that one
specific model is cheaper than another. A `TOP VALUE` cutoff also changes when
unrelated models enter the list. Do not infer pairwise price dominance from
rank membership or rank order.

## Procedure

1. Resolve a specific, first-party list price for every eligible model. Convert
   input/output prices to one documented blended cost. Exclude unknown prices;
   do not invent a fallback cost.
2. Form candidate and peer sets within one provider family and the product's
   intelligence frontier (for example, the visible `TOP 20`). Keep an explicit
   near-leader gate if cheap but much weaker models must be suppressed.
3. Emit a recommendation pair only when both inequalities hold:

   ```text
   candidate.score > peer.score
   candidate.blendedCost < peer.blendedCost
   ```

4. Rank valid pairs by higher candidate score, then higher peer score, then
   larger direct saving. Use `TOP VALUE` only as a later tie-breaker or display
   signal, never as the proof that a pair is cheaper.
5. Display the candidate and peer scores, both `$/M` costs, intelligence gain,
   and saving percentage. Keep the compact state terse, but make the expanded
   state auditable.
6. Add focused regression cases: a costly high-score model versus a cheaper
   low-score model must return no pair; a cheaper, higher-score candidate over
   an expensive peer must return the expected pair; removing a `TOP VALUE`
   membership must not change pair validity.

## Verification

- Run the model-ranking test suite and assert the price-direction cases.
- Refresh with current source data and inspect the rendered pair.
- Confirm the UI never calls a pair an inversion without showing both prices.

## High-Risk Actions

- Do not compare models across provider families unless the product explicitly
  defines that comparison.
- Do not substitute a global value rank, estimated provider average, or stale
  price for a missing model-specific price.
- Do not label a cheaper but lower-scoring model as an intelligence inversion.
