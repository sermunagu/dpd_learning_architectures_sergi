# Executed validation and reproducibility

Initial root HEAD: `1600d268c38378ad0d4fb689e7ca64dcb438f418`.
Initial root status: `## main...origin/main`, no changes. The nested repository
was already one local commit ahead of its own remote; that preexisting state
was preserved. No commit, push, reset, clean or restoration was performed.

## Executed

MATLAB R2026a 26.1.0.3203278, CPU. `diagnose.m` completed with exit code 0.
Primary outputs are in `tp0f242878_e7a5_4587_93ac_7eda9246e580/`.

- Loaded saved October dense, P310 point and bundle; 84->12->2 dimensions
  verified by actual array arithmetic and parameter enumeration. Saved
  features are reconstructed as double, weights are single.
- Asserted exact equality of stored dense/bundle normalization statistics
  and statistics independently recomputed on identification rows.
- Asserted sample equality of centered October raw input/target against
  the saved experiment. No April record was substituted.
- Asserted exact P310 direct prediction equality with its stored full-signal
  reference and with the public bundle inference path.
- Reconstructed the dense and sparse mathematical network formula with
  double matrix arithmetic. Relative prediction discrepancies of 9.6830e-8
  and 8.4643e-8 are recorded, not claimed bitwise equal to single network
  arithmetic. This validates scaling and phase restoration to that precision.
- Enumerated actual learnables: dense 1046, sparse 296 nonzero weights plus
  14 nonzero biases. All weights outside every sparse mask are exactly zero.
- Computed full/identification/evaluation NMSE, absolute MSE/MAE, equal-count
  input and target amplitude deciles, 20 time blocks, error concentration,
  feature correlations/SVD/scales, activation saturation/variation and
  layer/channel connectivity. No training routine is called.
- Independently recalculated the three measured pre-CFR imitation NMSEs
  against raw October y, and read the recorded RF NMSE fields.
- Inventoried four saved DPD experiment sources; separately inspected the
  existing structural-zero comparison CSVs, including the real April P310
  result and four synthetic P20 controls. These are prior results, not runs
  performed in this task.

`verifyExtras.m` is a separate read-only supplemental check of linear saved
predictions, measured pre-CFR signals and the radial/quadrature loss terms.
Its completed console log and `loss_components.csv` are in
`tp5a080fb0_4cba_4bf2_ad94_e39144b14241/`. The first attempt in
`tp50e31d28_f61a_4acf_822e_3a46651e7e4c/` stopped at an assumed 1e-12 relative
linear tolerance; GMP's actual discrepancy is 8.105e-12 relative and
1.421e-12 dB NMSE. The final diagnostic reports errors instead of asserting
that unsupported equality. PN-IQ is exact. No data or production fix was made.
Only inference/analysis was repeated. `checkcode` reported two formatting
alignment warnings at diagnose.m lines 87/88; neither is a runtime error.

### Continuation on 2026-11-04

Read all four existing files and recovered both successful previous runs and
the preserved aborted attempt. Side-effect inspection found only new unique
diagnostic-directory writes plus temporary path/diary state; no source/data
or checkpoint mutation, training call, or RF call. Existing outputs were kept.

Ran only `verifyExtras(true)` in MATLAB R2026a. This optional mode reconstructs
the bundle and reads linear references, then returns before repeated dense
prediction, loss-component and measured-signal analysis. The necessary added
global-maximum error and separate NMSEs are saved with recovered L2/max errors
in `tpe4a4c804_5b22_4e47_b722_3de03b117090/reference_metrics.csv`. Exit code 0.
GMP: max absolute 1.49552e-12, L2 relative 8.10499e-12, max/global-reference
1.09412e-11; saved/reconstructed NMSE -38.4154774055449/-38.4154774055435 dB,
absolute change 1.42109e-12 dB. PN-IQ is exactly equal, both NMSEs
-38.8754853637991 dB. Assertions require both relative measures <1e-9 and
NMSE delta <1e-8 dB; both pass. The budgets are numerical, not statistical,
and much tighter than the earlier 1e-5/1e-4 dB scientific thresholds.

Re-read saved sigmaI=.0125525119001017 and sigmaQ=.00375762280052252;
(sigmaI/sigmaQ)^2=11.1592477280154 verifies the physical Q/I loss weighting.
No new training was used to infer its causal effect. The two old indentation
warnings were fixed by expanding the compact for/if headers in diagnose.m;
the completion run's checkcode calls report no warnings for either script.
The full diagnose function was not rerun for this formatting-only change.

`continuation_integrity.csv` confirms all 326 tracked files and 151 original
October data/checkpoint/report files still have their original SHA256 hashes.
The four existing diagnostic files were updated in place; only the new
reference-summary directory and continuation integrity summary were added.

SHA256 manifests `source_before.csv` and `data_before.csv` cover 326 tracked
files and 151 October data/checkpoint/report files respectively. The first
after-analysis audit found zero changes in both sets. `integrity.csv` records
the final repeated check. Other existing artifacts were only read.

## Reproduce without training

From the main repository root:

```matlab
addpath('sergi_pniq_dpd/diagnostics/pnnn_root_cause');
diagnose;
verifyExtras;
```

To reproduce ONLY the final reference checks, call `verifyExtras(true)`.
Reproduction commands are optional; all documented outputs already exist.

Each invocation makes a new unique output directory under this folder.
It requires the local, ignored scientific data listed in REPORT.md; a fresh
Git clone alone does not contain those captures/checkpoints. Scripts fail at
missing files rather than substituting another experiment. Only existing
MATLAB/Deep Learning Toolbox and standard MATLAB functions are used.

The scripts call `buildPhaseNormDataset`, `predictPNNN`, `applyDPDModels` and
`nmseComplexDb`. They do not invoke `runDPDSweep`, `trainDensePNNN`,
`fitSparsePNNN`, `pruneAndFineTunePNNN`, `trainnet`, `adamupdate` or hardware
entry points. Inspection of training source is not execution of training.

## Pending and limits

- No dense or fine-tuning experiment proposed in REPORT.md was run. Any
  changed-loss, residual, width, seed or alternative-mask training requires
  separate authorization. Consequently none is claimed to improve NMSE.
- No final optimizer trajectory or stationarity/gradient convergence test;
  checkpoints lack the complete optimization history required for a strong
  convergence conclusion. A final loss value or epoch count cannot prove it.
- No independent capture/generalization test or repeat RF measurement; the
  evaluation complement shares a temporally correlated record and target-
  informed selection. No confidence intervals from pseudo-independent samples.
- Measured PNNN pre-CFR x and reconstructed checkpoint prediction differ by
  7.825e-7 relative L2. Their exact export/scaling/rounding linkage remains
  unresolved; the report does not claim they are the identical stored signal.
- No fresh channel-15 intervention or global phase-rotation sweep here;
  sparse zero connectivity proves no direct contribution, and prior April
  interventions are identified explicitly as historical evidence.
- No full physical Jacobian or causal feature importance analysis; activation
  derivatives and output-weight norms are descriptive local proxies.
- Saturation conditioned on the worst-error events, and finer temporal
  transient analysis, remain inexpensive read-only follow-ups if needed.
- Equal-count amplitude bins describe the observed distribution, not fixed
  physical operating intervals extrapolatable to another capture.

## Final repository status

Observed root status after the new artifacts only (unchanged at continuation closure):

```text
## main...origin/main
?? sergi_pniq_dpd/diagnostics/pnnn_root_cause/
```

`git diff --stat` is empty: no tracked files changed. New untracked files are
not included in that command. They comprise REPORT.md, VALIDATION.md, two
MATLAB scripts, source/data integrity manifests and uniquely located derived
CSV/MAT/log evidence. No tests, logs or derived results were written outside
this new diagnostic directory.
