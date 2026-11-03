# Minimal production integration of dlaccelerate

## Change

Three production code files changed, plus the research README:

- `config/getComparisonConfig.m`: `cfg.pruning.useAcceleration = false`.
- `toolbox/pnnn/fitSparsePNNN.m`: forward that execution option from the run
  configuration into the fine-tuning runtime configuration, including when
  the saved dense source predates this option. Missing means false.
- `toolbox/pnnn/pruneAndFineTunePNNN.m`: select either `@modelLoss` or
  `dlaccelerate(@modelLoss)` before the existing loop, explicitly clearing the
  accelerated cache once per fit. Both paths use the same loop and updates.
- `README.md`: activation, numerical-equivalence scope and resume semantics.

Dense training and validation-based epoch selection keep the original path.
Only the already selected fixed-epoch training can opt into acceleration.
No masks, architectures, seeds, permutations, optimizer, normalization,
learning-rate schedule or epoch counts changed. Checkpoint schemas and
`runDPDSweep.m` are unchanged. Existing line endings were preserved.

Activation for a new run, from the research directory:

```matlab
addpath('config', 'DPD');
cfg = getComparisonConfig(pwd);
cfg.pruning.useAcceleration = true;
% Supply cfg to runDPDSweep(captureFile, budgets, cfg) or trainDPD(..., cfg).
```

Set false to restore historical execution. Resuming a directory continues to
load its saved configuration; a third configuration argument does not override
it. Old configurations without the field remain historical. Existing points
are reused, never retrained merely because an execution option was introduced.

## Isolated integration test

MATLAB R2026a (26.1.0.3203278), CPU, 2026-11-02. `testIntegration.m` created
unique fixtures under
`tp1c6b2c54_8f0f_4ebd_a111_5c358073e2b7/results/` in this directory.

Both fixtures contain real P310 slices of the existing linear checkpoints and
a copy of `sweep_dense_source.mat` from the original completed sweep
`tpf1484cb1_eb1d_4fe1_9d7e_13899ee8f7e5`. Calling the unmodified production
`runDPDSweep` on each fixture exercises an incomplete one-budget resume:
reuse linear and dense checkpoints, train only P310, save the point and model
bundle. There is no dense training, linear fitting, full sweep or hardware use.

Small one-epoch controls establish missing-option/false equivalence and
unchanged epoch selection when toggling the option, and warm both execution
paths. The two requested fixed-epoch integration fits each run all 164 epochs.

| Production path | Fine-tuning seconds | Entire one-budget call seconds |
|---|---:|---:|
| Historical (legacy configuration without the field) | 62.4 | 70.951 |
| Accelerated (true) | 32.0 | 39.452 |

Fine-tuning times are the existing production timer's output, rounded to
0.1 seconds. The surrounding call includes feature preparation, predictions,
checkpoint I/O and reporting. This single P310 pair gives about 1.95x speedup
and 48.7% less fine-tuning time; it does not replace the prior multi-budget
stable estimate of 1.87x and 46.6%.

## Scientific and checkpoint checks

All assertions passed:

- Historical production weights and full predictions are bitwise equal to
  the pre-integration P310 scientific checkpoint.
- Accelerated production weights are bitwise equal to the saved validated
  experimental P310 run (`session_acceleration/.../run_05.mat`).
- Original versus accelerated: prediction relative L2 1.162013e-7, signed
  NMSE delta +4.105812e-7 dB, weight maximum absolute difference 1.907349e-6
  and weight relative L2 6.316139e-7. The agreed 1e-5 prediction and 1e-4 dB
  NMSE thresholds pass; original/accelerated weights are not bitwise equal.
- Masks and final RNG are exactly equal, all pruned parameters remain exactly
  zero, network state is unchanged and each model has exactly 310 active
  parameters. The accelerated RNG also matches the saved experimental run.
- New `models_P0310.mat` reloads with the same learnables and masks as its
  point checkpoint, with the original model field schema and 164 epochs.
- A second call on each fixture reuses the completed point and skips the
  dense source and training entirely. RNG and result tables are unchanged.
  SHA256 hashes of `experiment.mat`, linear/fixed-linear/dense checkpoints,
  `pnnn_target_0310.mat` and `models_P0310.mat` remain identical before and
  after this completed resume. Aggregate reports can be regenerated locally,
  exactly as production resume already does.
- One-budget fixtures cannot cover an operating-point stabilization window;
  production handles this expected condition without selecting a point.
- `checkcode` reports no warnings for the three modified production files.

The before/after source audit covers 224 existing MATLAB/Markdown files:
only the four intended research files changed. All 133 original scientific
checkpoint/result files in the existing manifest retain their SHA256 hashes.
No tutor file, original scientific result or checkpoint was modified. No
commit or push was made.

## Evidence and reproduction

The unique fixture directory contains `integration.log`, `timing.csv`,
`comparison.csv/.mat`, per-mode logs in MAT files and isolated checkpoints.
This directory also holds source before/after manifests, `integrity.csv` and
the four original files as `.before` snapshots for review/reversal.

To intentionally repeat the integration test (two new 164-epoch fits):

```matlab
addpath('sergi_pniq_dpd/diagnostics/acceleration_integration');
testIntegration
```

It always creates a fresh diagnostic directory. No production code depends
on this diagnostic folder. The production change can be disabled by the flag;
the diagnostic evidence can be removed independently.
