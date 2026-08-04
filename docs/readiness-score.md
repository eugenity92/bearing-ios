# The readiness score

A number from 0 to 100 describing how today's physiology compares to your own recent
baseline. It is computed entirely on device from three HealthKit signals.

**This is a heuristic, not a measurement.** It has not been validated against any
clinical or athletic outcome. It cannot diagnose anything, predict anything, or tell you
whether to train. Read it as "today looks unusual for me" or "today looks typical for
me" and nothing more. The limitations at the bottom of this page are not boilerplate —
they are the reasons the number can be wrong.

## Inputs

| Signal | HealthKit type | Weight |
|---|---|---|
| Heart rate variability | `heartRateVariabilitySDNN` | 0.50 |
| Resting heart rate | `restingHeartRate` | 0.30 |
| Sleep duration | `sleepAnalysis` | 0.20 |

Each is compared against the preceding 28 days, today excluded. Every value is optional
throughout: gaps in HealthKit are normal, not exceptional.

## Component 1 — heart rate variability (0.50)

SDNN is right-skewed and closer to log-normal than normal, so the comparison is made on
the natural log rather than the raw value. This is standard practice in the HRV
literature and it materially changes the result: without it, a day 10 ms above your mean
scores differently depending on whether your mean is 30 ms or 90 ms.

```
x = ln(today)
μ = mean(ln(v) for v in baseline)
σ = max(sampleStdDev(same), 0.05)
z = (x − μ) / σ
score = clamp(50 + 25z, 0, 100)
```

So your own average scores 50, two standard deviations above scores 100, and two below
scores 0. The σ floor prevents a division by zero and stops an implausibly flat baseline
from producing enormous z-scores.

## Component 2 — resting heart rate (0.30)

The same shape, without the log transform — resting heart rate is roughly symmetric
around a personal baseline — and **inverted**, because lower is better:

```
z = (μ − today) / max(sampleStdDev, 1.0)
score = clamp(50 + 25z, 0, 100)
```

The floor is 1 bpm.

## Component 3 — sleep duration (0.20)

Scored against absolute hours, **not** against your own baseline. That is deliberate:
normalising sleep to a personal average would award a perfect score to someone who
reliably sleeps five hours, which is precisely the person the number should not
reassure.

| Hours slept | Score |
|---|---|
| ≤ 4.0 | 0 |
| 4.0 – 7.5 | linear, 0 → 100 |
| 7.5 – 9.0 | 100 |
| 9.0 – 11.0 | linear, 100 → 85 |
| ≥ 11.0 | 85 |

Long sleep is penalised only mildly and bottoms out at 85. Oversleeping is a weak signal,
not a bad one, and treating it as a failure would be an opinion the data does not support.

## Combining them

A component is used only if today's value exists. The two baseline-relative components,
HRV and resting heart rate, additionally require at least 7 baseline days; sleep does not,
because it is scored against absolute hours and never consults the baseline. Surviving
weights are renormalised to sum to 1.

If the surviving weight is below 0.5, no score is produced and the app says so. In
practice: HRV alone is enough (0.50), resting heart rate and sleep together are enough
(0.50), but sleep alone (0.20) or resting heart rate alone (0.30) are not. Someone
without a wearable therefore sees an honest "not enough data" rather than a number
invented from a single weak signal.

## Confidence

Taken from the smallest baseline day count among the components actually used:

| Baseline days | Confidence |
|---|---|
| < 7 | component dropped |
| 7 – 13 | low — "still learning your baseline" |
| 14 – 27 | medium |
| ≥ 28 | high |

## Bands

| Score | Band |
|---|---|
| 0 – 39 | Low |
| 40 – 59 | Fair |
| 60 – 79 | Good |
| 80 – 100 | High |

## Sleep aggregation

Total sleep is not a sum of sample durations. Two corrections are applied first:

**Overlapping samples are merged.** If you wear an Apple Watch and also run a
third-party sleep tracker, HealthKit contains two overlapping sets of `sleepAnalysis`
samples covering the same night. Adding them produces fourteen-hour nights. Intervals are
merged into their union before being summed.

**Only asleep stages count.** `inBed` and `awake` are excluded; `core`, `deep`, `rem` and
`unspecified` are included.

**A night belongs to the day it ends.** Sleep is bucketed from 18:00 on the previous day
to 12:00 on the current one, so a night that crosses midnight lands on one day rather
than being split across two. An afternoon nap falls outside that window and is ignored.
The arithmetic uses `Calendar`, never a fixed 86,400 seconds, so daylight-saving
transitions are handled correctly.

## Limitations, stated plainly

- **HealthKit's HRV is not overnight HRV.** Apple Watch samples `heartRateVariabilitySDNN`
  opportunistically through the day. Whoop and Oura report HRV measured over a fixed
  overnight window, which is a different and more stable quantity. A daily mean of
  opportunistic samples is noisier and is affected by what you were doing when the
  samples happened to be taken. This is the single largest source of error in the score.
- **SDNN is a coarse HRV measure.** RMSSD is generally preferred for day-to-day readiness
  because it is less affected by respiration and recording length. HealthKit does not
  expose RMSSD, so SDNN is what is available.
- **The weights are a judgement call.** 0.50 / 0.30 / 0.20 is a considered guess, not a
  fitted model. Nothing here was trained on outcome data, because there is no outcome
  data.
- **A z-score assumes a stable baseline.** After illness, travel across time zones, or a
  training-load change, the 28-day baseline describes a person you no longer are, and the
  score will be confidently wrong for a couple of weeks.
- **Nothing here is validated.** No claim is made that a high score predicts performance
  or that a low score predicts anything at all.
