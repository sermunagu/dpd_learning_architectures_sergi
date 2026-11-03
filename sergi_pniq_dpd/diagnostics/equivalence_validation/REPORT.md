# Extended dlaccelerate scientific equivalence validation

## Decision

All seven tested budgets pass the user-specified preliminary criteria.
For this capture, saved dense source, seed, CPU execution and 164-epoch
procedure, the accelerated variant is scientifically equivalent within those
tolerances. This is numerical equivalence, not bitwise identity of every model.
The evidence supports considering a separately authorized integration; none
has been made. It does not establish equivalence for every capture, seed,
MATLAB version, device or all 49 accelerated budgets, nor RF equivalence.

## Method and provenance

- MATLAB R2026a, CPU, 20 MATLAB computational threads, 2026-11-02.
- Scientific source: `results/dpd_sweep/tpf1484cb1_eb1d_4fe1_9d7e_13899ee8f7e5`
  under the research root, from `experiment20261023T102742_xy.mat`.
- Original references: immutable `pnnn_target_0020.mat`, `0070`, `0100`,
  `0290`, `0310`, `0400`, `0500` in that source directory.
- Four new accelerated fits only: P20, P70, P290 and P500. Each starts from
  `sweep_dense_source.mat`, using the saved normalization, configuration,
  seed, identification rows and 164 fixed epochs. No dense training or sweep.
- P100/P310/P400 reuse completed accelerated runs 06/05/04 from
  `../session_acceleration/tp705818e5_a36d_45e4_ae24_88e83faabad1`.
  Original controls from that study already established checkpoint identity.
- The existing diagnostic `sessionPrunePNNN` helper was reused unchanged.
  The only experimental execution change remains `dlaccelerate(@modelLoss)`;
  its cache is explicitly cleared at each fit. Optimizer, batch order,
  learning-rate schedule, pruning and masks are unchanged.
- There are 49,151 identification samples, 48 batches per epoch (1024 and
  a final 1023), 7,872 updates per fit and 491,520 full-signal predictions.
- RNG reference: replay seed 100042 and the 164 original `randperm(49151)`
  calls; this state is exactly equal to the saved final original P100 control.
  Checkpoints do not themselves provide a saved final RNG reference.
- The four new fits were saved before analysis. The first analysis stopped
  because it assumed the original sweep had a selectable operating point.
  The diagnostic was corrected to handle the same no-selection outcome as
  production. Only saved-network analysis was rerun, with successful exit;
  no completed training was repeated. Both new MATLAB files pass `checkcode`
  without reported warnings.

Output directory: `tp140925cd_b795_4d9a_9dd3_c2bcb8fb7af6` here.

## Acceptance results

Prediction relative L2 is `norm(new-old)/norm(old)` over the full complex
signal, evaluated in double precision from the actual outputs. NMSE delta is
accelerated minus original; positive means slightly worse. Thresholds are
strictly less than 1e-5 and 1e-4 dB, respectively.

| P | Evidence | Prediction relative L2 | NMSE delta (dB) | Result |
|---:|---|---:|---:|---|
| 20 | New fit | 0 | 0 | PASS |
| 70 | New fit | 0 | 0 | PASS |
| 100 | Reused fit | 0 | 0 | PASS |
| 290 | New fit | 1.130600e-7 | +6.737520e-8 | PASS |
| 310 | Reused fit | 1.162013e-7 | +4.105812e-7 | PASS |
| 400 | Reused fit | 1.193506e-7 | +9.414106e-8 | PASS |
| 500 | New fit | 1.187231e-7 | +2.731503e-7 | PASS |

The worst prediction error is 83.8 times below its limit; the worst absolute
NMSE difference is 243.6 times below its limit. Maximum pointwise absolute
prediction difference is 2.686345e-8 in the signal's native units.

All seven have exactly equal masks, all pruned entries exactly zero in both
networks, identical zero locations across all parameters, exactly P active
parameters and P nonzero active parameters in both networks, exact final RNG
and unchanged network state. The protected 14 biases remain active.
Pruned parameter counts for ascending P are 1026, 976, 946, 756, 736, 646, 546.

The evaluation subset also passes: maximum prediction relative L2
1.192784e-7 and maximum absolute NMSE delta 3.631268e-7 dB. The maximum
identification NMSE difference is 8.365583e-7 dB. This evaluation subset is
the saved sweep's development/evaluation subset, not an independent test
capture. Both the original and accelerated inference use the same function.

## Weight differences

The table includes all learnable weights and biases. Pruned entries are zero
in both, so they contribute no error to the norms. Bitwise equality is not an
acceptance requirement. Layer-level detail is in `weight_details.csv`.

| P | Maximum absolute error | Relative L2 error | Changed parameters |
|---:|---:|---:|---:|
| 20 | 0 | 0 | 0/20 |
| 70 | 0 | 0 | 0/70 |
| 100 | 0 | 0 | 0/100 |
| 290 | 1.907349e-6 | 6.230340e-7 | 276/290 |
| 310 | 1.907349e-6 | 6.316139e-7 | 294/310 |
| 400 | 2.026558e-6 | 6.404926e-7 | 387/400 |
| 500 | 1.430511e-6 | 5.072014e-7 | 482/500 |

## Dependence on budget and experimental conclusions

There is a visible pattern: the three tested low budgets are exactly equal,
while the four tested budgets from P290 upwards differ slightly. All four
nonzero NMSE changes have the same positive sign. This small directional
effect should be documented, rather than described as exact neutrality.
However, neither weight error nor NMSE delta increases monotonically with P.
Prediction relative error stays near 1.1e-7 to 1.2e-7 in that group; P500's
weight error is smaller than P290/P310/P400's. These observations do not
locate a transition budget or establish a statistical law from seven points.

No measured experimental conclusion changes:

- The evaluation-NMSE ordering of the seven PNNN budgets is unchanged.
- Family ranking (GMP-DOMP, PN-IQ-GMP, PNNN) is unchanged at each tested P.
  The smallest original gap between adjacent families there is 0.132936 dB,
  far larger than the measured perturbations.
- Replacing just these seven PNNN metrics in the saved 49-budget table leaves
  the complete PNNN evaluation ranking unchanged. Other budgets retain their
  original metrics; this is a hybrid sensitivity check, not a new sweep.
- The saved original sweep has **no automatically selected operating point**:
  the configured joint-stabilization condition is not met. The original and
  hybrid tables both produce `selectOperatingPoint:NoJointlyStabilizedPoint`.
  This matches the saved sweep's empty selection and selection reason.
  P310 is a tested laboratory budget, not an automatically selected point in
  this saved sweep. No claim that acceleration preserves an automatic P310
  selection is supported or needed.

## Execution and trace interpretation

The four new accelerated fits took P20 31.736 s, P70 29.694 s, P290 29.727 s
and P500 29.450 s (120.607 s total). These are fit times, excluding loading,
feature preparation and analysis. There are no fresh original timing controls
for these four points, so they do not independently establish a speedup ratio.
The prior stable comparison remains 58.798 s original versus 31.425 s
accelerated on average: 1.87x and 46.6% less fine-tuning time. The unexplained
193 s initial original run is excluded from that comparison.

All four new fits have 99.974593% cache hit rate and 4% occupancy, consistent
with two traces for the two minibatch sizes. Those statistics alone cannot
prove correctness. The previous six saved trace-reuse checks, which vary
inputs, targets, network weights and batch size, remain applicable evidence;
they were not rerun. New masks/RNG/checkpoint comparisons add end-to-end
evidence over additional sparse budgets.

MathWorks documents that traces depend on array sizes, formats and data types,
while changing network parameter values can reuse a trace. This is intended
behavior, not reuse of old parameter values. The cache is shared by functions
with the same underlying function and must be explicitly cleared after code
changes. The diagnostic clears it per fit. See
[Deep Learning Function Acceleration](https://www.mathworks.com/help/deeplearning/ug/deep-learning-function-acceleration-for-custom-training-loops.html).

The observed small, repeatable differences are consistent with floating-point
changes in an optimized computation graph accumulating through Adam. Their
exact internal arithmetic cause has not been isolated. No stale-trace behavior
is indicated by the available tests. Future changes to modelLoss, layers,
hidden state, input types or randomness need a fresh compatibility review.

## Recommendation and artifacts

The current experimental implementation satisfies the requested scientific
tolerances across all seven tested budgets. Together with the previous stable
timings, this makes dlaccelerate a well-supported candidate for the next
integration decision. Preserve the same training procedure, explicit cache
handling, masks/zero checks and numerical provenance if integration is later
authorized. Do not label accelerated checkpoints bitwise identical.

New files are confined to this diagnostic directory: this report, README,
`runExtendedValidation.m`, `analyzeExtendedValidation.m`, integrity summaries
and the unique run directory. The latter contains four accelerated networks,
environment and RNG references, the initial execution log, `equivalence.csv`,
`weight_details.csv`, `family_rankings.csv` and `conclusions.csv/.mat`.
The numerical CSV includes original/accelerated full, identification and
evaluation NMSE, all structural checks, errors, timings and cache statistics.
The original execution log retains the first analysis error for provenance;
the final conclusions files record the successful corrected analysis.

Before/after SHA256 checks cover the existing manifests of 50 production
source files and 133 scientific checkpoint/result files. All remain unchanged.
No production or tutor files were edited, no checkpoints overwritten, no
hardware accessed and no commit or push performed.
