# Validation record

MATLAB 26.1.0.3203278 (R2026a), PCWIN64, CPU, 20 MATLAB threads.
Completed run: `tp1442baa6_833f_4abe_a213_602d50180629` (RUN below).
The protocol was written before diagnosis/training and is hash-verified.
This record reports existing tests; it does not authorize another real fit.

## Provenance and diagnostic gates

| Check | Criterion | Observed |
|---|---|---|
| Source LS checkpoint inference | isequal to saved prediction | Pass |
| October centered input/target | isequal to saved experiment | Pass |
| Stored features/targets | Reuse cached double arrays, 84/2 columns | Pass |
| Original id/complement indices | isequal, 49,151 / 442,369 | Pass |
| Masks / normalization / inherited hidden values | isequal against prior sources | Pass |
| Historical 164 shuffle orders / final RNG | isequal to saved reference | Pass |
| Initial normalized loss | Absolute discrepancy <=1e-7 | 6.54380519e-11 |
| Initial permitted output gradient | L2 <=1e-5 | 6.86247164e-8 |
| Native/double normalized prediction | Relative L2 <=1e-6 | 1.64259595e-7 |
| Native/double AD, every array | L2 difference <=1e-6+1e-3*norm(gDouble) | Pass; largest difference 1.49766812e-8 |
| Six deterministic double FD checks | abs(FD-AD) <=1e-8+1e-4*abs(AD) | Pass; max 8.00109111e-13 |
| Native AD versus the same FD | Recorded, not a separate gate | Max abs 1.37976074e-9 |
| Diagnosis read-only | Exact weights/state/masks/normalization/RNG | Pass |

The FD clone used double learnables only for diagnosis, with step
eps(double)^(1/3)*max(1,abs(parameter)). Real training kept single learnables
and double normalized CB inputs/targets. Diagnostic gradients are weighted
by actual batch sample counts, accumulated in double in fixed natural order.
They are not the shuffled online training gradients. This same endpoint
convention was retained before and after continuation.

`gradient_finite_differences.csv`, `gradient_precision.csv`, both
`gradient_*.mat`, and the global/per-neuron CSVs retain the full evidence.
The initial metadata-reader failure is recorded in the separate failed
preflight log and explained in REPORT. It occurred before gradient evaluation
or updates. The corrected reader uses saved original metadata, not defaults.

## Synthetic loop checks

The same `trainHiddenNetwork` worker was tested on a deterministic 3->4->2
network, 1,027 rows, batch 1,024, two epochs/four Adam updates. This included
unequal output masks and nonzero raw output derivatives (L2 0.270864683054).

- Explicit mixed loss versus helper loss: absolute error zero.
- Output weights and biases: exact equality after each Adam update, checked
  before remasking; output freeze cannot be concealed by restoration.
- Only permitted fc1 coordinates changed; all pruned coordinates stayed zero.
- All predictions finite; expected permutations and final RNG exact.
- Schedule at epochs 1/41/42/82/83/123/124/164 equals
  2e-4/2e-4/1.9e-4/1.9e-4/1.805e-4/1.805e-4/1.71475e-4/1.71475e-4.
- Caller RNG restored after the synthetic check.

The actual values and flags are in `preflight.mat` and
`saved_verification.json`. All gates passed before the sole real update run.

## Real fit and saved artifact checks

The real fit used 164 epochs and exactly 7,872 updates. Each of the 164
permutations matched the original reference. Seed was 100042, Twister;
Adam began with empty moments and iteration zero. Its historical call and
local R2026a defaults were retained. No acceleration, feature regeneration,
new initialization, pruning, rate/epoch search or development-based selection
was used.

Output values passed exact checks on every update, before mask reapplication.
Every epoch had 310 active nonzero coefficients and 736 exact pruned zeros.
All 273 allowed hidden weights and 12 biases changed. No output value changed.
Architecture, masks, normalization and state stayed exact. First/second Adam
moments at all frozen/pruned coordinates were exactly zero in the final model
and stored checkpoints.

| Saved point | Updates | Output equality | Active parameters |
|---|---:|---|---:|
| Epoch 41 | 1968 | Exact | 310 |
| Epoch 82 | 3936 | Exact | 310 |
| Epoch 123 | 5904 | Exact | 310 |
| Final epoch 164 | 7872 | Exact | 310 |

The final saved network was loaded again and reproduced `inference.mat`
exactly. `verifyHiddenBits` separately compared IEEE-754 representations by
typecasting single output weights/biases to uint32, including signed zeros.
All three checkpoints and the final model were bitwise identical to the
source LS readout; `output_bit_verification.json` records the results.
The final shuffle RNG matched the historical reference. Inference,
endpoint analysis and saved-artifact verification preserved their caller RNG.
Training intentionally resets and advances the RNG according to its historical
shuffle procedure; this is distinct from read-only diagnosis preserving RNG.

The repeat-preflight, repeat-train and repeat-analysis guards were invoked
and caught their expected errors before computation or writes. They did not
perform additional training or analysis. Checkpoint checks validate saved
states; no resumed optimization was run. `checkpoint_verification.csv` and
`saved_verification.log` record this validation.

## Metric consistency and decision

Recomputed unchanged mixed/LS/PN-IQ reference metrics match the prior saved
tables: maximum tolerated differences were 1e-10 dB NMSE, 1e-18 physical MSE
and 1e-15 mixed loss. Stored amplitude order/boundaries were reused; boundary
equality was exact, and LS decile MSE matched within 1e-18. No baseline was
retrained. All final predictions and hidden activations were finite.

The full metric definitions remain those in earlier diagnostics. I/Q errors
use the input-rotated physical coordinate system. Native identification loss
has a different batch/precision reduction path from double prediction-derived
loss; both are reported explicitly. Weighted angular error uses target energy.
Activation percentiles use nearest ranks, and tails mean h<0.01 or h>0.99.

Predeclared criteria relative to LS on the development complement:

- NMSE gain >=0.10 dB: **0.290993619317 dB, pass**.
- Physical Q MSE increase <=10%: **-3.541719976292%, pass**.

These are descriptive checks, not confidence intervals or significance tests.
The increasing final hidden-gradient norm is recorded, not suppressed or
treated as a stationarity claim. No RF metrics were inferred or calculated.

## Static analysis and file integrity

`checkcode` reports no messages for the six pretraining MATLAB files.
`verifyHiddenResult.m` has only three "Extra comma is unnecessary" style
messages at its compact try/catch statements (lines 39-41). The additional
read-only `verifyHiddenBits.m` passes checkcode without messages. These do not affect
the passing guard checks and were left intact after verification. No scientific
code was changed after the fit to improve a result.

All 645 pre-existing protected files match SHA-256 before versus after.
`integrity_before.csv` and `integrity_after.csv` retain absolute paths and
hashes. All seven pretraining source/protocol hashes match in
`code_before_training.csv` and `code_after_training.csv`.
`artifacts_manifest.csv` covers the completed diagnostic files, excluding
itself. `repository_before.json`, `repository_after.json` and
`integrity_summary.json` document scope and checks.

Branch and commit remain main / 1600d268c38378ad0d4fb689e7ca64dcb438f418.
Tracked and staged diffs are empty. The only additional untracked directory
is `pnnn_hidden_continuation`; six pre-existing untracked diagnostic directories
are untouched. No production/tutor file, original checkpoint, hardware code,
CFR, commit or push was changed/invoked.

## How the artifacts were produced

From the repository root, the already executed sequence was:

```matlab
addpath('sergi_pniq_dpd/diagnostics/pnnn_hidden_continuation');
out = runHiddenContinuation('preflight');
runHiddenContinuation('train', out);
analyzeHiddenContinuation(out);
verifyHiddenResult(out);
```

Do not execute this sequence again: the saved run and its guards deliberately
prevent an accidental second experiment. To inspect results without fitting:

```matlab
out = fullfile('sergi_pniq_dpd','diagnostics','pnnn_hidden_continuation', ...
    'tp1442baa6_833f_4abe_a213_602d50180629');
F = load(fullfile(out,'final_model.mat'));
metrics = readtable(fullfile(out,'metrics.csv'));
checks = jsondecode(fileread(fullfile(out,'saved_verification.json')));
```

The entry point loads only the authorized saved sources and separates
preflight, training and analysis. Results are retained without redundant
feature caches or figures. Any new conditional LS study requires a new task;
none was executed here.
