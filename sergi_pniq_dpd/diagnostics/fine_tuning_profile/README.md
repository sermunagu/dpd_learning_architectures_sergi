# PNNN fine-tuning diagnosis (no optimization)

Everything in this directory is diagnostic and may be removed as one unit.
It is outside the production toolbox path. Production source/checkpoints are
read-only inputs. No dense training and no full sweep are launched.

## Reproduce

From sergi_pniq_dpd in MATLAB R2026a:

```matlab
addpath(fullfile(pwd,'diagnostics','fine_tuning_profile'));
runBenchmark
% Use the newly printed diagnostic directory:
analyzeBenchmark('<diagnostic-directory>')
```

runBenchmark selects the saved sweep
results/dpd_sweep/tpf1484cb1_eb1d_4fe1_9d7e_13899ee8f7e5 explicitly.
It rebuilds features using experiment.mat's already prepared x/y (no second
DC removal), and loads sweep_dense_source.mat. It uses the saved fixed-epoch
options from fitSparsePNNN, including the exact identification rows, seed,
mini-batch size, fine-tuning duration, schedule and protected masks.

P100, P310 and P400 each run the full 164 epochs. timedPrunePNNN is a copy of
pruneAndFineTunePNNN with only timers, diagnostic storage and sparse progress
messages added. It retains the same arithmetic and operation order. Timers
separately cover minibatch indexing/transposition/dlarray construction,
dlfeval, gradient masks, adamupdate, and weight-mask reapplication. Learning
rate calculation, setup, epoch permutations, integrity checks and timer/storage
overhead are reported in OtherSeconds. CPU execution is required by these timers.

P310 also runs the unmodified production function for all 164 epochs to check
instrumentation equality (learnables, masks and final RNG state). All three
runs compare learnables/masks and predictions against their existing point
checkpoints. No benchmark networks are saved over production models.

A supplemental one-epoch MATLAB call-tree profile runs AFTER full benchmarks.
Its inclusive times overlap and must not be added to stage totals. It is used
only to inspect internal call costs; the main timing results cover full runs.
PredictionSeconds separately times the same normalization, two predictions and
NMSE calculations used by fitSparsePNNN. It excludes minor count/table assembly.
Initial checkpoint loading and full feature construction are recorded separately.

## Files

- runBenchmark.m: repeatable driver; each run gets a unique subdirectory.
- timedPrunePNNN.m: instrumented snapshot, NOT an optimized replacement.
- analyzeBenchmark.m: tables and call-tree summary for a completed run.
- inspect_checkpoints.m / inspection.log: selection of the source sweep.
- source_before.csv / checkpoints_before.csv: SHA256 preservation manifests.
- benchmark.log: console transcript from the initial diagnostic run.
- tp*/: timing arrays, environment, CSV summaries and one-epoch profiler data.
- REPORT.md: measured findings, limitations and prioritized proposals.

If production code changes, this instrumented snapshot must be reviewed or
regenerated before benchmarking again. No optimization has been implemented.
