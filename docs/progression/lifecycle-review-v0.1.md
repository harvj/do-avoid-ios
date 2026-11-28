# Do/Avoid iOS lifecycle review v0.1

The audited baseline is `6e87564`. The production Field has no six-level progression system. It displays daily status and an archive flag, using the same translucent yellow for every Do and gray for every Avoid regardless of age or history. Native clocks in this iteration expose existing prototype milestones. Recent activity and Momentum remain experimental Dev Lab models. The [landing v0.2](../design/landing-v0.2/) level numbers, palette steps, and example countdowns were review fixtures.

## Production behavior and stored history

- Creating an item stores an ID, title, kind, creation instant, local Gregorian creation day, an empty entry list, and an inactive archive flag. Day 1 has elapsed age zero. An absent entry on or after creation means **unmarked** for Do and **no violation marked** for Avoid. For Avoid this is treated as a successful status by the app without evidence that avoidance occurred. A mark means completed for Do or violated for Avoid. A stored entry with `isMarked=false` has the same daily status as an absent entry, but may retain a note, count, and entry ID. Days without interaction create no entries or synthetic completions or violations.
- The Field toggles today’s mark. The read-only landscape Timeline shows historical status. The store supports editing an entry and setting or clearing the archive flag, but the app currently has no user-facing controls for those operations. The status function also reports explicitly imported entries dated before creation. Days before creation without a record are outside the lifetime.
- At baseline the Field and Timeline provide no progression projection. Their default opacity is 0.45 for yellow Do and 0.25 for gray Avoid. A marked Do shows a check, an unmarked Do has no icon, and an Avoid shows a check or a red cross. There is no Level 1–6, no production maturity cue, and no history-dependent fill or persistent strength.
- The unused Do prototype computes one unit per marked day for Do, including imported marks. It derives completed cycles as integer division by 40 and phase as remainder modulo 40. Avoid has zero durable units. These values are recomputed from entries and never written separately. Individual marks are retained through any absence and can be corrected. Notes and counts carry no progression weight. The unused `missedDays` helper counts missing **records** from creation through the requested day, including today. An explicitly unmarked record therefore reduces that count, and the helper is not a streak penalty.
- The Avoid prototype measures elapsed civil days since the latest recorded violation on or before the viewed day, or creation if none. It clamps elapsed at zero. States are solid at 0–6, cracked at 7–20, open at 21–39, and overgrown at 40+. Its retirement helper would set the archive flag for overgrown Avoid items, but no production caller invokes it. These states do not color the Field.
- The archive flag is a single saved Boolean without dated events. A flagged item remains visible with an Archived label in the Field and cannot be toggled there. A restore through the store clears the flag without changing history. Nothing pauses elapsed time, resets the cycle, or reconstructs past intervals. The production Timeline has no archive history. An unarchived item’s current status follows its entries immediately.

## Native Field clock semantics

| Item | Estimate | Recalculation |
| --- | --- | --- |
| Do | `40 - (marks through viewed day mod 40)` civil days, assuming a new completion each day starting tomorrow. The ring fills with completed units within the current cycle. | Each recorded completion lowers the estimate by one until the 40th, when the next cycle starts at 40. Missing a day leaves the estimate and accumulated marks unchanged. Correcting a mark can move it in either direction. Future-dated entries do not count in a forecast as of today. |
| Avoid | `next threshold - elapsed` civil days assuming no further violations. The ring fills across the current state’s interval, of length 7, 14, or 19 days. | An unmarked day advances elapsed even with the app closed. A new violation restarts elapsed at zero immediately. Removing the violation reveals the previous most recent violation or the creation date. Overgrown has no further threshold, so the Field shows a dash. |
| Archived or before creation | No estimate. | Archived rows omit the clock. The Field omits rows before creation. Restoring an item exposes the current estimate based on its retained history. |

These estimates are conditional distances to existing milestones. There is no estimator for future adherence or for a next visible level. Marking today or publishing a successful store edit updates the same history snapshot the Field observes. App activation and existing significant time and time-zone change handlers refresh the date. No new background scheduling, persisted progression fields, or automatic archive behavior are involved. Both display switches default on and persist independently in app preferences.

## Dev Progression Lab at the audited baseline

The Lab is compiled only with `DOAVOID_LAB`. Production configurations define `DOAVOID_PRODUCTION` and reject the combination of both flags. The separate Dev app uses the same native Field behavior outside the Lab. The Lab owns in-memory examples, deterministic dates and marks, temporary edits, and an illustrative archive interval. Scrubbing before creation yields no projection. Moving past the fixture’s last mark treats subsequent days as unmarked. Resetting examples restores the fixtures. Lab projections never write to app history.

Let `a` be age in civil days, and `k` the days from each recorded mark to the viewed day. A Do mark is a completion and an Avoid mark is a violation. Neither candidate stores accumulated strength.

| Candidate | Exact default rule |
| --- | --- |
| Recent activity | Let `W = max(1, Int(window))`, default 21. Count marks between `max(creation, today - (W - 1))` and today inclusive. Divide by `min(a + 1, W)` to obtain `f`. Do strength is `f`, Avoid strength is `1 - f`. Marks before creation and after the viewed day are excluded. |
| Momentum | Let `H = max(1, recovery)`, default 10. Include marks from `max(creation, today - (ceil(H) - 1))` through today. Compute `w = count - sum(k) / H`. Do strength is `min(1, w / max(1, H / 2))`. Avoid strength is `max(0, 1 - w)`. Multiple recent violations add their weights and can pin strength at zero. |
| Maturity | For either candidate, mature when `a >= maturityAge` and strength `>= maturityStrength`. Defaults are 60 days of elapsed age and 0.70 strength. The first eligible day is Day 61. Maturity can be lost and regained with strength. |
| Rendering | Lab strength continuously maps to opacity `0.14 + strength × (intensity - 0.14)`, with intensity 0.72 by default. Classic uses yellow/gray. Garden uses teal/purple and Mineral uses blue/orange. The Lab shows maturity and allows an illustrative archived interval. It has no discrete levels or candidate countdown. |

Tune exposes Recent window 3–90 days, Momentum recovery 2–60 days, maturity age 7–730 days in 7-day steps, maturity strength 0.10–1.00 in 0.05 steps, palette, and color intensity 0.20–1.00. The default candidate is Recent. The archive fixture overrides the flag from reference day minus 65 through minus 9, then clears it at minus 8. Its gap in marks is scripted. Both candidates still project from age and marks during that interval. No archive pause rule exists.

## Day-by-day scenarios

Day 1 is creation. Production visible **level is undefined on every row**, and the production fills stay fixed. The table’s strength and `M` maturity are Lab-only, rounded for display. Do total is the retained marked-day count, so completed cycles and phase are its quotient and remainder by 40. Avoid state is the prototype threshold state, and every explicitly recorded violation remains in history. The clock columns show the new native milestone forecasts in civil days. A dash indicates no next prototype milestone. Neither model has an estimate to a visible level.

For a Do with no interaction at all, total stays 0, both candidates stay at 0 strength, maturity never starts, and the conditional Do estimate stays 40. An Avoid with no interaction follows the no-violation column, even if the user never opens the app. If the first action on Day 1 is an Avoid violation, Recent and Momentum both become 0 on Day 1, the first prototype threshold is still seven days away, and the violation remains recorded. From Day 2 without further violations, Recent rises as `1 - 1/min(day number, 21)` through Day 21 and becomes 1 on Day 22. Momentum rises by 0.1 per day to 1 on Day 11.

Each setback below starts after 90 days of explicit Do completions and zero recorded Avoid violations. During a setback the Do is unmarked and the Avoid has an explicit violation each day. On resumption Do is marked daily, and Avoid records no further violations. An Avoid **absence from the app** differs from a recorded violation and simply continues the zero-violation timeline.

### Creation before the first mark

| Day | Do total | Do Recent | Do Momentum | Do clock | Avoid state | Avoid Recent | Avoid Momentum | Avoid clock |
| --- | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: |
| 1 | 0 | 0.00 | 0.00 | 40 | solid | 1.00 | 1.00 | 7 |

### Daily completions and no recorded violations

| Day | Do total | Do Recent | Do Momentum | Do clock | Avoid state | Avoid Recent | Avoid Momentum | Avoid clock |
| --- | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: |
| 1 | 1 | 1.00 | 0.20 | 39 | solid | 1.00 | 1.00 | 7 |
| 2 | 2 | 1.00 | 0.38 | 38 | solid | 1.00 | 1.00 | 6 |
| 3 | 3 | 1.00 | 0.54 | 37 | solid | 1.00 | 1.00 | 5 |
| 4 | 4 | 1.00 | 0.68 | 36 | solid | 1.00 | 1.00 | 4 |
| 5 | 5 | 1.00 | 0.80 | 35 | solid | 1.00 | 1.00 | 3 |
| 6 | 6 | 1.00 | 0.90 | 34 | solid | 1.00 | 1.00 | 2 |
| 7 | 7 | 1.00 | 0.98 | 33 | solid | 1.00 | 1.00 | 1 |
| 8 | 8 | 1.00 | 1.00 | 32 | cracked | 1.00 | 1.00 | 14 |
| 14 | 14 | 1.00 | 1.00 | 26 | cracked | 1.00 | 1.00 | 8 |
| 21 | 21 | 1.00 | 1.00 | 19 | cracked | 1.00 | 1.00 | 1 |
| 22 | 22 | 1.00 | 1.00 | 18 | open | 1.00 | 1.00 | 19 |
| 30 | 30 | 1.00 | 1.00 | 10 | open | 1.00 | 1.00 | 11 |
| 39 | 39 | 1.00 | 1.00 | 1 | open | 1.00 | 1.00 | 2 |
| 40 | 40 | 1.00 | 1.00 | 40 | open | 1.00 | 1.00 | 1 |
| 41 | 41 | 1.00 | 1.00 | 39 | overgrown | 1.00 | 1.00 | — |
| 60 | 60 | 1.00 | 1.00 | 20 | overgrown | 1.00 | 1.00 | — |
| 61 | 61 | 1.00 M | 1.00 M | 19 | overgrown | 1.00 M | 1.00 M | — |
| 79 | 79 | 1.00 M | 1.00 M | 1 | overgrown | 1.00 M | 1.00 M | — |
| 80 | 80 | 1.00 M | 1.00 M | 40 | overgrown | 1.00 M | 1.00 M | — |
| 90 | 90 | 1.00 M | 1.00 M | 30 | overgrown | 1.00 M | 1.00 M | — |

### 1-day setback starting Day 91

| Day | Do total | Do Recent | Do Momentum | Do clock | Avoid state | Avoid Recent | Avoid Momentum | Avoid clock |
| --- | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: |
| 90 | 90 | 1.00 M | 1.00 M | 30 | overgrown | 1.00 M | 1.00 M | — |
| 91 | 90 | 0.95 M | 0.90 M | 30 | solid | 0.95 M | 0.00 | 7 |
| 92 | 91 | 0.95 M | 0.92 M | 29 | solid | 0.95 M | 0.10 | 6 |
| 93 | 92 | 0.95 M | 0.94 M | 28 | solid | 0.95 M | 0.20 | 5 |
| 94 | 93 | 0.95 M | 0.96 M | 27 | solid | 0.95 M | 0.30 | 4 |
| 96 | 95 | 0.95 M | 1.00 M | 25 | solid | 0.95 M | 0.50 | 2 |
| 98 | 97 | 0.95 M | 1.00 M | 23 | cracked | 0.95 M | 0.70 M | 14 |
| 99 | 98 | 0.95 M | 1.00 M | 22 | cracked | 0.95 M | 0.80 M | 13 |
| 101 | 100 | 0.95 M | 1.00 M | 20 | cracked | 0.95 M | 1.00 M | 11 |
| 105 | 104 | 0.95 M | 1.00 M | 16 | cracked | 0.95 M | 1.00 M | 7 |
| 106 | 105 | 0.95 M | 1.00 M | 15 | cracked | 0.95 M | 1.00 M | 6 |
| 111 | 110 | 0.95 M | 1.00 M | 10 | cracked | 0.95 M | 1.00 M | 1 |
| 112 | 111 | 1.00 M | 1.00 M | 9 | open | 1.00 M | 1.00 M | 19 |
| 113 | 112 | 1.00 M | 1.00 M | 8 | open | 1.00 M | 1.00 M | 18 |
| 131 | 130 | 1.00 M | 1.00 M | 30 | overgrown | 1.00 M | 1.00 M | — |

### 2-day setback starting Day 91

| Day | Do total | Do Recent | Do Momentum | Do clock | Avoid state | Avoid Recent | Avoid Momentum | Avoid clock |
| --- | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: |
| 90 | 90 | 1.00 M | 1.00 M | 30 | overgrown | 1.00 M | 1.00 M | — |
| 91 | 90 | 0.95 M | 0.90 M | 30 | solid | 0.95 M | 0.00 | 7 |
| 92 | 90 | 0.90 M | 0.72 M | 30 | solid | 0.90 M | 0.00 | 7 |
| 93 | 91 | 0.90 M | 0.76 M | 29 | solid | 0.90 M | 0.00 | 6 |
| 94 | 92 | 0.90 M | 0.80 M | 28 | solid | 0.90 M | 0.00 | 5 |
| 95 | 93 | 0.90 M | 0.84 M | 27 | solid | 0.90 M | 0.00 | 4 |
| 97 | 95 | 0.90 M | 0.92 M | 25 | solid | 0.90 M | 0.10 | 2 |
| 99 | 97 | 0.90 M | 1.00 M | 23 | cracked | 0.90 M | 0.50 | 14 |
| 100 | 98 | 0.90 M | 1.00 M | 22 | cracked | 0.90 M | 0.70 M | 13 |
| 102 | 100 | 0.90 M | 1.00 M | 20 | cracked | 0.90 M | 1.00 M | 11 |
| 106 | 104 | 0.90 M | 1.00 M | 16 | cracked | 0.90 M | 1.00 M | 7 |
| 107 | 105 | 0.90 M | 1.00 M | 15 | cracked | 0.90 M | 1.00 M | 6 |
| 112 | 110 | 0.95 M | 1.00 M | 10 | cracked | 0.95 M | 1.00 M | 1 |
| 113 | 111 | 1.00 M | 1.00 M | 9 | open | 1.00 M | 1.00 M | 19 |
| 114 | 112 | 1.00 M | 1.00 M | 8 | open | 1.00 M | 1.00 M | 18 |
| 132 | 130 | 1.00 M | 1.00 M | 30 | overgrown | 1.00 M | 1.00 M | — |

### 3-day setback starting Day 91

| Day | Do total | Do Recent | Do Momentum | Do clock | Avoid state | Avoid Recent | Avoid Momentum | Avoid clock |
| --- | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: |
| 90 | 90 | 1.00 M | 1.00 M | 30 | overgrown | 1.00 M | 1.00 M | — |
| 91 | 90 | 0.95 M | 0.90 M | 30 | solid | 0.95 M | 0.00 | 7 |
| 92 | 90 | 0.90 M | 0.72 M | 30 | solid | 0.90 M | 0.00 | 7 |
| 93 | 90 | 0.86 M | 0.56 | 30 | solid | 0.86 M | 0.00 | 7 |
| 94 | 91 | 0.86 M | 0.62 | 29 | solid | 0.86 M | 0.00 | 6 |
| 95 | 92 | 0.86 M | 0.68 | 28 | solid | 0.86 M | 0.00 | 5 |
| 96 | 93 | 0.86 M | 0.74 M | 27 | solid | 0.86 M | 0.00 | 4 |
| 98 | 95 | 0.86 M | 0.86 M | 25 | solid | 0.86 M | 0.00 | 2 |
| 100 | 97 | 0.86 M | 0.98 M | 23 | cracked | 0.86 M | 0.40 | 14 |
| 101 | 98 | 0.86 M | 1.00 M | 22 | cracked | 0.86 M | 0.70 M | 13 |
| 103 | 100 | 0.86 M | 1.00 M | 20 | cracked | 0.86 M | 1.00 M | 11 |
| 107 | 104 | 0.86 M | 1.00 M | 16 | cracked | 0.86 M | 1.00 M | 7 |
| 108 | 105 | 0.86 M | 1.00 M | 15 | cracked | 0.86 M | 1.00 M | 6 |
| 113 | 110 | 0.95 M | 1.00 M | 10 | cracked | 0.95 M | 1.00 M | 1 |
| 114 | 111 | 1.00 M | 1.00 M | 9 | open | 1.00 M | 1.00 M | 19 |
| 115 | 112 | 1.00 M | 1.00 M | 8 | open | 1.00 M | 1.00 M | 18 |
| 133 | 130 | 1.00 M | 1.00 M | 30 | overgrown | 1.00 M | 1.00 M | — |

### 7-day setback starting Day 91

| Day | Do total | Do Recent | Do Momentum | Do clock | Avoid state | Avoid Recent | Avoid Momentum | Avoid clock |
| --- | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: |
| 90 | 90 | 1.00 M | 1.00 M | 30 | overgrown | 1.00 M | 1.00 M | — |
| 91 | 90 | 0.95 M | 0.90 M | 30 | solid | 0.95 M | 0.00 | 7 |
| 92 | 90 | 0.90 M | 0.72 M | 30 | solid | 0.90 M | 0.00 | 7 |
| 93 | 90 | 0.86 M | 0.56 | 30 | solid | 0.86 M | 0.00 | 7 |
| 94 | 90 | 0.81 M | 0.42 | 30 | solid | 0.81 M | 0.00 | 7 |
| 95 | 90 | 0.76 M | 0.30 | 30 | solid | 0.76 M | 0.00 | 7 |
| 96 | 90 | 0.71 M | 0.20 | 30 | solid | 0.71 M | 0.00 | 7 |
| 97 | 90 | 0.67 | 0.12 | 30 | solid | 0.67 | 0.00 | 7 |
| 98 | 91 | 0.67 | 0.26 | 29 | solid | 0.67 | 0.00 | 6 |
| 99 | 92 | 0.67 | 0.40 | 28 | solid | 0.67 | 0.00 | 5 |
| 100 | 93 | 0.67 | 0.54 | 27 | solid | 0.67 | 0.00 | 4 |
| 102 | 95 | 0.67 | 0.80 M | 25 | solid | 0.67 | 0.00 | 2 |
| 104 | 97 | 0.67 | 0.98 M | 23 | cracked | 0.67 | 0.40 | 14 |
| 105 | 98 | 0.67 | 1.00 M | 22 | cracked | 0.67 | 0.70 M | 13 |
| 107 | 100 | 0.67 | 1.00 M | 20 | cracked | 0.67 | 1.00 M | 11 |
| 111 | 104 | 0.67 | 1.00 M | 16 | cracked | 0.67 | 1.00 M | 7 |
| 112 | 105 | 0.71 M | 1.00 M | 15 | cracked | 0.71 M | 1.00 M | 6 |
| 117 | 110 | 0.95 M | 1.00 M | 10 | cracked | 0.95 M | 1.00 M | 1 |
| 118 | 111 | 1.00 M | 1.00 M | 9 | open | 1.00 M | 1.00 M | 19 |
| 119 | 112 | 1.00 M | 1.00 M | 8 | open | 1.00 M | 1.00 M | 18 |
| 137 | 130 | 1.00 M | 1.00 M | 30 | overgrown | 1.00 M | 1.00 M | — |

### 30-day setback starting Day 91

| Day | Do total | Do Recent | Do Momentum | Do clock | Avoid state | Avoid Recent | Avoid Momentum | Avoid clock |
| --- | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: |
| 90 | 90 | 1.00 M | 1.00 M | 30 | overgrown | 1.00 M | 1.00 M | — |
| 91 | 90 | 0.95 M | 0.90 M | 30 | solid | 0.95 M | 0.00 | 7 |
| 92 | 90 | 0.90 M | 0.72 M | 30 | solid | 0.90 M | 0.00 | 7 |
| 93 | 90 | 0.86 M | 0.56 | 30 | solid | 0.86 M | 0.00 | 7 |
| 95 | 90 | 0.76 M | 0.30 | 30 | solid | 0.76 M | 0.00 | 7 |
| 97 | 90 | 0.67 | 0.12 | 30 | solid | 0.67 | 0.00 | 7 |
| 100 | 90 | 0.52 | 0.00 | 30 | solid | 0.52 | 0.00 | 7 |
| 105 | 90 | 0.29 | 0.00 | 30 | solid | 0.29 | 0.00 | 7 |
| 111 | 90 | 0.00 | 0.00 | 30 | solid | 0.00 | 0.00 | 7 |
| 120 | 90 | 0.00 | 0.00 | 30 | solid | 0.00 | 0.00 | 7 |
| 121 | 91 | 0.05 | 0.20 | 29 | solid | 0.05 | 0.00 | 6 |
| 122 | 92 | 0.10 | 0.38 | 28 | solid | 0.10 | 0.00 | 5 |
| 123 | 93 | 0.14 | 0.54 | 27 | solid | 0.14 | 0.00 | 4 |
| 125 | 95 | 0.24 | 0.80 M | 25 | solid | 0.24 | 0.00 | 2 |
| 127 | 97 | 0.33 | 0.98 M | 23 | cracked | 0.33 | 0.40 | 14 |
| 128 | 98 | 0.38 | 1.00 M | 22 | cracked | 0.38 | 0.70 M | 13 |
| 130 | 100 | 0.48 | 1.00 M | 20 | cracked | 0.48 | 1.00 M | 11 |
| 134 | 104 | 0.67 | 1.00 M | 16 | cracked | 0.67 | 1.00 M | 7 |
| 135 | 105 | 0.71 M | 1.00 M | 15 | cracked | 0.71 M | 1.00 M | 6 |
| 140 | 110 | 0.95 M | 1.00 M | 10 | cracked | 0.95 M | 1.00 M | 1 |
| 141 | 111 | 1.00 M | 1.00 M | 9 | open | 1.00 M | 1.00 M | 19 |
| 142 | 112 | 1.00 M | 1.00 M | 8 | open | 1.00 M | 1.00 M | 18 |
| 160 | 130 | 1.00 M | 1.00 M | 30 | overgrown | 1.00 M | 1.00 M | — |

### What a return changes

- Do retains the 90 completions, two completed cycles, and 10 units into cycle three during each setback. The first completion on return increases the phase to 11 and drops the clock from 30 to 29. After that, the cycle advances by one per recorded completion. It does not refill automatically.
- Recent gives a single missed Do date or Avoid violation weight `1/21` in an established history. It remains in the window through 20 days after the mark or miss, then drops out. With 30 consecutive setbacks, both candidates reach zero and a return rebuilds strength gradually. Recent first regains default maturity after 15 successful days and reaches full strength after 21. Momentum Do regains maturity after 5 completed days and reaches full strength after 8. Momentum Avoid after 7 or 30 violations regains maturity after 8 clean days and full strength after 10.
- A recorded Avoid violation moves the prototype back to solid immediately, even from overgrown. Each successive violation holds it there and keeps the next estimate at seven days. Recovery hits cracked 7 days after the **last violation**, open after 21, and overgrown after 40. The old violations are still recorded. Clearing an erroneous latest violation can move the forecast or state immediately.
- A real Level 6 item or Level 6 setback cannot occur in the audited code. The closest distinct cases are reaching maximum Lab strength, meeting the Lab maturity threshold, completing a 40-mark Do cycle, and reaching overgrown Avoid. Maximum strength and maturity can regress as described above, a cycle survives missed days, and overgrown can regress immediately after a violation. None of these cases defines Level 6.

### Archive and restore example

Suppose the store archives both items on Day 91 and clears both flags on Day 98. The Do had 90 prior completions and the Avoid’s only violation was on Day 90. No marks are recorded during archive. Production shows the Archive cue, retains history, and still has no visible progression level.

| Day | Store action | Do total / clock | Avoid prototype / clock |
| --- | --- | --- | --- |
| 90 | Both active | 90 / 30 days | Solid / 7 days |
| 91 | Archive both | 90 / hidden | Solid / hidden |
| 96 | Still archived | 90 / hidden | Solid / hidden |
| 97 | Still archived | 90 / hidden | Cracked / hidden |
| 98 | Restore both, before marking | 90 / 30 days | Cracked / 13 days |
| 98 | Complete the Do | 91 / 29 days | Cracked / 13 days |

The Do resumes from its retained count immediately. The Avoid forecast reflects elapsed time during archive immediately. Under Lab calculations, filtering old marks out of the lookback still happens on archived days. In this example the Do on Day 98 before marking has Recent strength `13/21` and Momentum strength `0.06`. The Avoid has Recent strength `20/21` and Momentum strength `0.80`. Clearing the archive flags alone changes neither projection. These archive dates describe the example, since production only saves each item’s latest flag.

## Decisions for owner review

1. Choose a production strength model, or keep strength out of the Field. Decide how six visible levels would map to the chosen model and whether the approved palette should encode those levels.
2. Decide whether unmarked Avoid days alone should confer maturation and whether maturity should decay, persist, or latch. Decide if a Do cycle and Avoid recovery milestones should remain the basis for clocks after visible levels exist.
3. Define any user-facing edit, archive, and restore controls. Decide whether archive should pause progression, whether a restore restarts it, and whether the data model needs dated lifecycle events. Old archive dates cannot be inferred from the saved flag.
4. Decide whether future forecasts should continue to state ideal inputs or use an observed cadence with an explicit minimum history and uncertainty. The present estimate deliberately leaves those decisions open.

Source locations include [item history and prototypes](../../Models/DoAvoidItem.swift), [forecasts and Lab projections](../../Models/Progression.swift), [Lab controls](../../Views/ProgressionLab.swift), and [Field rendering](../../Views/FieldView.swift).
