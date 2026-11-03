# Session order and dlaccelerate: final report

2026-11-02. Production unchanged. No dense retraining or full sweep.
Completed run: tp705818e5_a36d_45e4_ae24_88e83faabad1.

## Speed, using a stable baseline

All 12 full fits completed in one MATLAB R2026a session, with saved dense source,
164 epochs, 49151 rows, 48 minibatches/epoch and identical seeds/configuration.
Four blocks: original ascending, accelerated descending, accelerated ascending,
original descending. Only P100/P310/P400 were trained, twice per variant.

| P | Original first block (s) | Original final stable block (s) | Accelerated two-run mean (s) |
|---|---:|---:|---:|
| 100 | 193.101 | 58.789 | 31.551 |
| 310 | 64.845 | 58.765 | 31.506 |
| 400 | 59.178 | 58.842 | 31.218 |
| Equal-budget mean | 105.708 | **58.798** | **31.425** |

The stable mean saving is **46.55% (1.871x)**, approximately 27.37 s per fit.
Do not use the raw 61.8% aggregate saving: it is inflated by the first 193 s run.
The final baseline block was chosen explicitly to compare all three budgets
under stable session conditions, not to cherry-pick a fast individual model.
The complete raw data, including the slow run, remain in summary.csv.

The historical 200-vs-60-second effect reproduced: P100 took 193.10 s initially
and 58.79 s at the end with identical weights and predictions. No sustained
session degradation was observed over this approximately 11.5-minute test.
Original late/early epoch-median ratios were 0.941, 0.968, 1.008, 0.970, 0.995,
1.016; accelerated ratios were 0.991, 0.987, 1.064, 0.998, 0.961, 0.950.
Early means epochs 2:41; late means 125:164. All epochs count in total time.

The initial slow fit used 463.6 process CPU seconds in 193.1 wall seconds
(2.40 CPU/wall), versus roughly 8 CPU/wall for stable original runs. This is
consistent with different effective CPU availability/utilization, but does not
identify scheduling, contention, power state, threading or caching as the cause.
No frequency/temperature telemetry or exclusive CPU reservation was collected.
Memory rose from 2745 MiB initially to about 3472 MiB, then stabilized. This
is not evidence of a progressive leak. A 12-fit test cannot rule out degradation
in a much longer 49-budget sweep.

## Numerical equivalence

Every original run equals its production checkpoint exactly. Repeated runs of
each variant/P also have identical learnables, masks and RNG, regardless of
budget order. All accelerated runs preserve masks, network state, RNG, active
parameter counts and exact zeros at every pruned position.

| P | Max absolute weight error | Relative weight infinity / L2 error | Max absolute prediction error | Relative prediction infinity / L2 error | NMSE delta (dB) |
|---|---:|---|---:|---|---:|
| 100 | 0 | 0 / 0 | 0 | 0 / 0 | 0 |
| 310 | 1.90735e-6 | 8.67639e-7 / 6.31614e-7 | 2.42144e-8 | 2.01755e-7 / 1.16201e-7 | +4.10581e-7 |
| 400 | 2.02656e-6 | 9.20260e-7 / 6.40493e-7 | 2.68635e-8 | 2.22481e-7 / 1.19351e-7 | +9.41411e-8 |

Infinity relative error is max(abs(new-old))/max(abs(reference)); L2 relative
error is norm(new-old)/norm(reference), across all parameters or all full-record
predictions. These are NOT maximum pointwise relative errors: division by tiny
or zero weights/samples would be misleading. Per-element mixed tolerances were
checked separately, including near-zero elements.

P310 NMSE changes from -35.1288921476265 to -35.1288917370453 dB; P400 from
-35.7354412250272 to -35.7354411308862 dB. P100 remains -26.4941653777923 dB.
Thus P100 is bitwise equal; P310/P400 are NOT bitwise equal despite nearly
unchanged scientific metrics. Do not describe the entire variant as exact.

An illustrative per-element criterion abs(delta)<=1e-7+1e-5*abs(reference)
passes full predictions for all P but FAILS weights for P310. It passes weights
for P100/P400. This criterion was exploratory, not a pre-agreed acceptance rule.
A norm-based criterion (relative L2 <=1e-6 for weights and predictions, absolute
NMSE delta <=1e-5 dB, exact masks/zeros/RNG) passes all three. Its scientific
acceptability must be agreed; a passing norm test does not erase the failed
stricter per-element test or prove equivalence for untested budgets/captures.

## Trace reuse and interpretation

Only the loss/gradient evaluation changes: create dlaccelerate(@modelLoss) once
per fit and pass it to dlfeval. All optimizer, minibatch and mask operations
remain unchanged. The accelerated loss has no RNG calls, file reads, mutable
external data or branches depending on sample values. Network, input and target
are explicit arguments. The cache is cleared per fit, so no trace is carried
from P100 to P310 or P400.

Each accelerated fit reports 99.9745935% hits and 4% occupancy of the default
50-entry cache, consistent with two traces for batches 1024 and 1023. High hit
rate alone is not a correctness check. Repeating both budget orders reproduces
exactly the same accelerated weights, and independent complete-checkpoint and
full-prediction comparisons show only the small discrepancies above.

A supplementary read-only evaluation test changes batch values, targets,
network learnables and batch length, then returns to the original arguments.
It compares cached vs uncached losses and gradients, without Adam or training.
Its results are stored in trace_reuse_checks.csv. No stale-output behavior was
found within the explicitly tested tolerance (1e-6 absolute + 1e-5 relative).
This is evidence against incorrect trace reuse for this function, not a proof
covering every future code change or input type.

The small deterministic differences are compatible with the changed execution
of a traced/optimized floating-point graph and their accumulation through Adam.
Their low magnitude, repeatability, unchanged masks/RNG and correct responses
to changed arguments support that interpretation. The exact internal fusion
or reduction responsible was NOT isolated; rounding is an interpretation,
not a demonstrated instruction-level cause.

MathWorks documents trace caching, input-pattern handling and caveats for
side effects, captured state and value-dependent control flow:
https://www.mathworks.com/help/deeplearning/ref/dlaccelerate.html
https://www.mathworks.com/help/deeplearning/ug/deep-learning-function-acceleration-for-custom-training-loops.html
Source changes require clearing the cache. Numeric frequently-changing inputs
that are not dlarray can trigger retracing; hidden mutable inputs can invalidate
assumptions. Those risks should be re-audited if modelLoss changes.

## Recommendation

**dlaccelerate is the strongest measured candidate for reducing average
fine-tuning time across the tested budgets**: about 46.6% versus the stable
original, consistently in both orders. Keep the experimental implementation
separate for now, as requested.

If exact bitwise identity is mandatory, do NOT integrate this variant: it fails
that requirement for P310/P400. Next investigate data movement/mask-container
changes with exact comparisons; the prior stage profile limits their opportunity.

If explicit numerical/scientific tolerances are acceptable, conditional
integration is worthwhile after fixing acceptance criteria in advance and
validating additional representative budgets/captures, especially sweep ends.
Preserve per-fit cache lifetime, exact masks/zeros/RNG and record the numerical
change. Do not silently change the production reference or present new models
as byte-identical. No optimization has been integrated in this task.

Separately, investigate CPU/thread availability under controlled diagnostic
conditions to explain the 193 s episode. Do not combine that unexplained
session effect with the demonstrated dlaccelerate speedup. Two repetitions per
variant/P are insufficient for a high-confidence full-sweep extrapolation.

## Evidence

summary.csv, epochs.csv, by_budget.csv, numerical_equivalence.csv,
trace_reuse_checks.csv, run_01.mat through run_12.mat, environment.mat,
session_timing.png and the diagnostic console logs. All live under diagnostics.
Production source/checkpoint SHA256 manifests were checked after analysis.
No production changes, checkpoint overwrites, dense training, full sweep,
commits or push. Analysis after completion used stored networks and inference/
gradient evaluations only; no completed training test was repeated.
