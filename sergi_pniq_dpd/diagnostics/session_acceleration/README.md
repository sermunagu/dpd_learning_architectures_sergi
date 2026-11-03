# Session-order and dlaccelerate experiment

Diagnostic-only experiment. Everything here is removable and outside production
paths. No production code, configuration or checkpoint is changed. No dense
training and no full parameter sweep is called.

From sergi_pniq_dpd in MATLAB R2026a:

```matlab
addpath(fullfile(pwd,'diagnostics','session_acceleration'));
runSessionBenchmark
% After completion, use the printed output directory:
analyzeSession('<output-directory>')
```

The driver loads the same latest completed sweep used in the previous diagnosis:
results/dpd_sweep/tpf1484cb1_eb1d_4fe1_9d7e_13899ee8f7e5.
Every fit starts from its saved dense source. Data, normalization, 49151 training
rows, minibatch 1024 (including the final 1023 samples), seed, schedule, masks,
Adam and all 164 epochs remain the same.

## Balanced schedule in ONE MATLAB process

1. Original: P100, P310, P400.
2. Accelerated: P400, P310, P100.
3. Accelerated: P100, P310, P400.
4. Original: P400, P310, P100.

This ABBA design puts original fits both early and late, includes both budget
orders for both variants, and gives equal weight to every tested budget. There
are two full fits per budget/variant, not 49-budget sweep runs. No pauses, cache
clears between blocks, new MATLAB sessions or parameter changes are introduced.
The loss-function cache is deliberately cleared on each accelerated fit so that
cache creation cost is INCLUDED and no cross-budget cache state is assumed.
Built-in dlnetwork machinery remains whatever the current session naturally has.

There is a separate one-epoch warmup/control against the unchanged production
function before the schedule. Original diagnostic results must match that
control exactly; accelerated differences are recorded rather than suppressed.
An initial exploratory session stopped at that strict accelerated equality check;
its environment-only output remains separate from the complete session.

## Experimental difference

sessionPrunePNNN.m is a production snapshot plus per-epoch wall/CPU timing and
cache statistics. Its original branch uses @modelLoss. Its experimental branch
creates dlaccelerate(@modelLoss) once before the loop, clears that cache, and
passes the resulting object to the SAME dlfeval call. No other optimization is
included. CheckMode remains the default none for performance measurement;
correctness is assessed independently after each complete fit.

Full-record predictions and all learnable tensors/masks are compared to the
saved production checkpoint. RNG state is compared to the first original fit
of the same P. Per-run saved learnables/masks/RNG permit cross-run checks.
Network state, max absolute parameter/prediction deviations and NMSE delta
are also recorded. Prediction, verification, checkpoint reading and diagnostic
I/O are outside the timed fit. Their small gaps remain part of session history.

## Files

- sessionPrunePNNN.m: experimental snapshot; never a production replacement.
- runSessionBenchmark.m: reproducible single-session driver.
- analyzeSession.m: tables and epoch-history plot.
- source_before.csv, checkpoints_before.csv: preservation manifests.
- session.log: completed-session transcript.
- tp*/: environment, summary.csv, epochs.csv and per-run numerical artifacts.
- REPORT.md: conclusions, exact/approximate equality and limitations.

Early/late epoch summaries use medians of epochs 2:41 and 125:164; epoch 1 is
excluded from that ratio to separate first-call cost. All epochs count toward
reported total time. CPU and memory measurements are descriptive; they are not
CPU-temperature/frequency telemetry and do not prove a cause for historical
200-second observations. Two repeats in one session do not provide a precise
confidence interval or a guarantee about hours-long full sweeps.
