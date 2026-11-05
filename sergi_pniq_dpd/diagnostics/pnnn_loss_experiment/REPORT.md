# PNNN P310: controlled fine-tuning loss experiment

Completed 2026-11-04. Exactly one new real-data fine-tune, 164 fixed epochs,
without acceleration. No production changes, dense training, baseline
retraining, sweep, hardware access, CFR, commits or pushes.

## Outcome

Changing only the fine-tuning loss improves full-signal imitation NMSE from
-35.128892 to -35.803688 dB (0.674796 dB). Identification improves 0.627190 dB
and the development complement improves 0.680132 dB. Total physical MSE
falls 14.3908%. This is a useful, limited positive result for the stated
objective, but not an improvement in every component: physical I MSE falls
24.8953%, Q MSE rises 21.2430%, and historical normalized loss rises 10.4872%.

The experiment supports a causal effect of this loss intervention on this
fixed-duration trajectory, starting from this historical dense network and
mask. It does not establish improved independent-capture generalization,
better RF linearization, a universally preferable loss, or a solution to the
remaining representation/optimization gap. The new P310 remains 3.071797 dB
worse than the frozen PN-IQ-GMP P310 reference (-38.875485 dB).

## Initial repository state and immutable sources

Root repository: `sermunagu/dpd_learning_architectures_sergi`, branch `main`,
HEAD `1600d268c38378ad0d4fb689e7ca64dcb438f418`. All 326 tracked files were
clean. The pre-existing `diagnostics/pnnn_root_cause/` was untracked and was
preserved. The nested project Git metadata was left untouched.

Paths below are relative to `sergi_pniq_dpd/`, except the capture:

- Capture: repository-root
  `results/experimentosSergi20261023/experiment20261023T102742_xy.mat`.
- Source directory: `results/dpd_sweep/tpf1484cb1_eb1d_4fe1_9d7e_13899ee8f7e5/`.
- `experiment.mat`: centered x=u and y=x_ILC, configuration, split and
  provenance. Centering the relocated raw capture reproduces x and y exactly.
- `sweep_dense_source.mat`: original dense network, normalization and saved
  duration. Saved best dense epoch 1223; selected fine-tune duration 164.
- `pnnn_target_0310.mat`: baseline network, masks and saved full prediction.
- `models_P0310.mat` and all other historical data remain unchanged.
- Original P310 RNG reference:
  `diagnostics/session_acceleration/tp705818e5_a36d_45e4_ae24_88e83faabad1/run_11.mat`.

The provenance retains the original capture path under root `results/`;
the capture now resides in its October subfolder. Exact centered-data equality
was checked against that copy. No April source was substituted. Baseline
inference reconstructed from the saved network equals its saved prediction
bit for bit, and its full NMSE matches the TAREA 01 reference within 1e-10 dB.
The TAREA 01 audit and prior experiments were not rerun.

## Intervention and mathematical equivalence

The original dense statistics are
sigmaI=0.0125525119001017 and sigmaQ=0.00375762280052252.
They were reused unchanged; recomputation on identification rows served only
as an exact verification. Neither target means nor physical units changed.

Let dz=[z_pred-z_target] and e_c=sigma_c*dz_c in the rotated physical frame.
For N samples, the historical loss is

    Lnorm = (1/(2*N))*sum(eI.^2/sigmaI^2 + eQ.^2/sigmaQ^2).

Define S=sigmaI^2+sigmaQ^2 and w_c=2*sigma_c^2/S. The weights are

    wI = 1.83551614008226
    wQ = 0.164483859917741
    mean([wI,wQ]) = 1.

For CB tensors of size 2 by N, the experimental implementation computes

    Lweighted = mean(w(:).*(z_pred-z_target).^2, "all")
              = mean(eI.^2+eQ.^2)/S.

The phase rotation has unit magnitude, so eI^2+eQ^2 is also the squared
complex error after restoring phase. Thus the new loss is exactly proportional
to physical complex MSE in real arithmetic, with a fixed positive factor 1/S.
The derivative with respect to z_pred(c,n) is w_c*dz(c,n)/N.
The old loss gives Q about 11.15925 times the physical weight of I; the new
loss gives both equal physical weight. Weights are cast to prediction
precision in the actual loss; floating-point rounding applies to the identity.

Unit mean weights remove an arbitrary common scaling choice. They do NOT
preserve the gradient norm or Adam trajectory. The effect observed here includes
the changed gradient allocation and its interaction with the unchanged
optimizer; it does not isolate a pure representation-capacity mechanism.

## Fixed protocol and implementation

- 491520 samples: 49151 identification rows and 442369 development rows.
  The complement is not an independent test set.
- Same phase rotation, 84 features, z-scores and 84 -> 12 sigmoid -> 2 network.
- Same magnitude-pruning mask: 273 hidden weights + 23 output weights,
  with 12+2 protected biases. All 736 pruned weights remain exactly zero.
- Original dense network is pruned afresh, not initialized from the already
  fine-tuned P310. The zero-update production call reconstructs this starting
  point and confirms exact mask equality.
- Seed 42 + fine-tune offset 100000 = 100042, twister; same per-epoch randperm.
  All 164 permutations are saved. The final RNG equals the saved historical
  original-control RNG exactly.
- Batch size 1024, 48 batches/epoch (last batch 1023), 7872 Adam updates.
- Learning rate 2e-4 * 0.95^floor((epoch-1)/41), fresh Adam moments,
  unchanged production adamupdate call and defaults; no validation selection.
- Learnables remain single precision, with the same production data path.
  Gradient masking and weight remasking are unchanged.
- MATLAB 26.1.0.3203278 (R2026a), PCWIN64, 20 configured computation threads,
  CPU arrays, useAcceleration=false. Console training verbosity is disabled.

`lossPrunePNNN.m` is a traceable diagnostic copy of the production helper.
Its only executable differences are its name, guards restricting this experiment
to fixed epochs without acceleration, passing the loss weights, and replacing
the loss expression with `weightedLoss`. `production_diff.txt` records the
comparison ignoring line-ending-only differences. Validation-mode code is
unreachable. No alternate production training implementation was installed.

Before real training, synthetic tests checked the scalar loss identity,
analytic gradients, 2-by-batch layout, phase restoration, and masking. One
synthetic 32-row update with weights [1,1] gives exactly the same learnables,
masks and final RNG as production; the weighted synthetic update preserves
all pruned zeros. These are not real-data baseline fits.

The sole real fit took **111.5319697 seconds**, excluding setup and analysis.
Its final model was saved before analysis. There is no concurrent baseline
timing measurement, so this number is not an acceleration comparison.

## NMSE and component errors

All complex NMSE values use 10*log10(sum(abs(prediction-y).^2)/sum(abs(y).^2))
on the identical indexed samples, before CFR. I/Q errors below are in the
phase-rotated physical frame. Negative delta is an improvement.

| Domain | Historical dB | Physical-loss dB | Delta dB | I MSE historical | I MSE new | Q MSE historical | Q MSE new |
|---|---:|---:|---:|---:|---:|---:|---:|
| Identification | -35.111657 | -35.738847 | -0.627190 | 1.400893e-7 | 1.065738e-7 | 4.141217e-8 | 5.052074e-8 |
| Development complement | -35.130808 | -35.810940 | -0.680132 | 1.398199e-7 | 1.048602e-7 | 4.120460e-8 | 4.992312e-8 |
| Full signal | -35.128892 | -35.803688 | -0.674796 | 1.398468e-7 | 1.050315e-7 | 4.122536e-8 | 4.998288e-8 |

| Full-signal quantity | Historical | Physical loss |
|---|---:|---:|
| Normalized I MSE | 0.000887546872 | 0.000666589444 |
| Normalized Q MSE | 0.002919698903 | 0.003539931711 |
| I share of physical error | 77.2326% | 67.7560% |
| Q share of physical error | 22.7674% | 32.2440% |
| Historical normalized loss | 0.001903622888 | 0.002103260578 |
| Physical weighted loss | 0.001054674977 | 0.000902898658 |

`comparison.csv` includes these quantities for every domain. The worsening
Q component is substantive, not a rounding effect. This is an objective-specific
tradeoff, not Pareto dominance. The >0.10 dB engineering threshold proposed in
TAREA 01 is passed on both identification and development NMSE; it is not a
statistical significance test or a waiver of the Q tradeoff.

## Error versus input amplitude

The same sorted input indices define ten equal-count deciles (49152 rows
each) for both models. No bin depends on either prediction. `amplitude.csv`
contains boundaries, physical MAE/MSE, normalized complex NMSE, each bin's
share of total error energy, and its share of target energy.

| Decile | Historical NMSE dB | New NMSE dB | MSE reduction | New error share | Target energy share |
|---|---:|---:|---:|---:|---:|
| 1 | -22.9561 | -24.4367 | 28.89% | 6.73% | 0.49% |
| 2 | -29.6972 | -30.8671 | 23.61% | 4.55% | 1.46% |
| 3 | -32.5225 | -33.5889 | 21.77% | 4.21% | 2.53% |
| 4 | -34.6988 | -35.6149 | 19.02% | 3.89% | 3.72% |
| 5 | -35.7551 | -36.6194 | 18.05% | 4.23% | 5.11% |
| 6 | -36.5678 | -37.4747 | 18.85% | 4.62% | 6.78% |
| 7 | -37.6906 | -38.5677 | 18.29% | 4.71% | 8.90% |
| 8 | -38.4900 | -39.1073 | 13.25% | 5.53% | 11.83% |
| 9 | -38.5475 | -39.1331 | 12.61% | 7.75% | 16.68% |
| 10 | -34.3535 | -34.7810 | 9.37% | 53.79% | 42.50% |

MAE also improves in all ten bins (4.64% to 12.39%). The highest-amplitude
decile remains dominant: its MSE falls from 9.200589e-7 to 8.338070e-7,
but its error share rises from 50.81% to 53.79% because other bins improve more.
The lowest-amplitude decile has only 0.491% of target energy; its relatively
poor NMSE alone is not evidence that it dominates the global error.

## Signals and inference complexity

| Quantity | Historical | Physical loss | ILC target |
|---|---:|---:|---:|
| RMS, native units | 0.02428076566 | 0.02427560322 | 0.02428680938 |
| 10 log10(mean power), native reference | -32.29475245 | -32.29659939 | -32.29259072 |
| PAPR before CFR, dB | 13.87975297 | 13.95608295 | 14.74795973 |
| Peak magnitude | 0.1200190060 | 0.1210526157 | 0.1326686930 |
| Relative L2 error to ILC | 0.01752085892 | 0.01621121536 | 0 |
| Relative L2 change from historical prediction | 0 | 0.00588748608 | -- |
| Active parameters | 310 | 310 | -- |
| Historical FLOPs/sample | 780 | 780 | -- |

Both predictions are finite complex vectors of length 491520 with no NaN/Inf.
The new RMS is slightly lower (-0.001847 dB power change); PAPR rises
0.076330 dB and peak magnitude rises about 0.86%. These are small changes
in native-scale offline signals, not a transmission clearance. Hardware
calibration, export scaling and all normal RF safety checks remain required.
No CFR was applied and no EVM/ACPR/RF result was inferred from these signals.

The FLOP value is the project's unchanged historical accounting convention,
not a measured runtime or a new exact count of elementary operations.
The inference graph, normalization, masks, activation and phase restoration
are unchanged; training loss adds no inference operation.

## Limits and next experiment

The intervention improves the stated total physical imitation objective for
one seed, one capture, one mask and one fixed budget. The dense initialization
was itself trained with the historical loss. This is neither a dense-loss
comparison nor an architecture-capacity test. Improvement of 0.231289 dB
over the historical dense network's full NMSE does not show that pruning
increases intrinsic capacity: the objectives and later optimization differ.

The complement has already informed development. Samples are not independent
RF captures; no confidence interval or independent generalization claim is
supported. The remaining 3.071797 dB PN-IQ gap and the Q degradation prevent
claiming that the original neural deficit has been solved. No convergence
trajectory was used to retune the learning rate, epochs or weights.

Recommended next experiment: freeze this loss/protocol and compare the two
saved models on a separate untouched capture, with the same preprocessing,
both I/Q metrics and amplitude bins, before any production adoption. A later
matched dense-training loss comparison could study whether the inherited
representation limits the benefit, but is a separate intervention requiring
authorization. Neither follow-up nor any RF measurement was executed.

## Artifacts and final state

Unique run: `tp15ee449b_7a1a_4442_a6ae_cdefa2453e8a/` in this directory.

- `experimental.mat`: experimental result, elapsed time, final RNG, provenance.
- `protocol.mat`: dense-derived masked initialization, exact recorded row
  permutations, expected RNG, source configuration, normalization and weights.
- `inference.mat`: experimental inference model and prediction, tables.
- `comparison.csv`, `delta_experimental_minus_baseline.csv`, `amplitude.csv`,
  `signals.csv`, `target_signal.csv`: numerical results.
- `execution.log`, `verification.log`, `training_started.mat`: execution evidence
  and repeat-training guard.
- `runLossExperiment.m`, `lossPrunePNNN.m`, `weightedLoss.m`,
  `analyzeLossExperiment.m`, `verifySavedExperiment.m`: isolated code.
- `VALIDATION.md`, `production_diff.txt`, `integrity_before.csv`,
  `integrity_after.csv`: validation and integrity evidence.

SHA-256 is unchanged for all 505 manifest entries: 326 tracked files, 151
historical data files and 28 prior-audit files. No historical file was
overwritten. Final root Git changes consist only of this new untracked
diagnostic directory and the pre-existing untracked TAREA 01 directory.
No commit, push, production integration or TAREA 03 was performed.
