# PNNN fixed-epoch fine-tuning diagnosis

Date: 2026-11-02. No optimization was implemented.

## Inputs and scope

Selected the latest complete DPD sweep available locally:
`results/dpd_sweep/tpf1484cb1_eb1d_4fe1_9d7e_13899ee8f7e5` (2026-10-28),
whose provenance names experiment20261023T102742_xy.mat. It contains the dense
source and P100/P310/P400 checkpoints. The older April-data sweep was not used.
The original console transcript containing the reported 8297.80 s was not found;
that number and 86.1% remain user-reported reference measurements.

Loaded experiment.mat and sweep_dense_source.mat; did not call runDPDSweep,
trainDensePNNN or any hardware function. Rebuilt full-record features from the
saved, already DC-prepared x/y. Each target starts from the SAME immutable dense
network, then follows production pruning and fixed-epoch fine-tuning exactly.

- MATLAB R2026a 26.1.0.3203278, Windows x64, Intel CPU, 20 MATLAB threads.
- 491520 record samples; 49151 identification rows; 84 input features.
- 164 saved fine-tuning epochs, minibatch 1024: 48 updates/epoch, 7872 total.
- The final minibatch has 1023 samples; it is preserved.
- Features/targets double, network parameters single; CPU execution.
- Saved learning-rate schedule, initial rate, seed 42 plus saved seed offset,
  shuffle order, masks, protected biases, loss and Adam operations unchanged.
- Loading: 1.74 s; full feature construction: 5.70 s, shared across the targets.

Production source and all 133 files in the selected sweep directory match their
pre-benchmark SHA256 manifests. The 50 enumerated production MATLAB files under
DPD/config/toolbox also match. All new files are confined to this diagnostic
folder. No checkpoints or scientific outputs were overwritten.

## Full-run results

Seconds measured by CPU wall-clock timers around the original statements:

| Stage | P100 | P310 | P400 | Aggregate share |
|---|---:|---:|---:|---:|
| Minibatch indices, transpose and dlarray construction | 5.8175 | 5.7693 | 5.5723 | 9.28% |
| dlfeval (forward, MSE and backward) | 46.595 | 41.326 | 40.320 | 69.39% |
| Gradient masks | 2.2508 | 2.1012 | 2.0985 | 3.49% |
| adamupdate | 5.8137 | 5.1742 | 5.0754 | 8.69% |
| Reapply masks to network weights | 5.1371 | 5.0177 | 4.9615 | 8.18% |
| Other/setup/checks/instrumentation | 0.9352 | 0.4420 | 0.4019 | 0.96% |
| **Total pruning + fixed-epoch fine-tuning** | **66.549** | **59.831** | **58.430** | **100%** |
| Subsequent normalization, predictions and NMSE | 0.9106 | 0.2064 | 0.2321 | separate |

Shares are sums across the three runs divided by summed total time, not sums
of inclusive MATLAB profiler times. The initial P100 run includes warm-up:
first epoch 5.262 s vs steady median 0.369 s. P310: first 0.520 s, steady
median 0.361 s; P400: first 0.371 s, steady median 0.355 s. Therefore the P100
wall-time excess is not evidence that pruning to P100 is intrinsically slower.

Uninstrumented production P310: **58.772 s**. Instrumented P310: 59.831 s,
1.80% higher. One sequential comparison cannot isolate timer overhead from
system variability, but it bounds the observed discrepancy in this execution.
There are no repeated independent full-run trials or confidence intervals.

### Numerical checks

All three instrumented runs matched their saved checkpoint learnables and masks
with isequal: maximum parameter difference **0**. Full-record predictions also
matched the saved predictions exactly. Instrumented and uninstrumented P310
matched learnables, masks and final RNG state exactly. Production mask-integrity,
active-budget and protected-bias checks executed normally.

No numerical change or speedup is claimed from this diagnosis.
The historical 8297.80/49 = 169.34 s per point is substantially above these local
measurements. Different session/load/warm-up conditions are possible explanations,
but were not established. Do not report the difference as an optimization gain.

## What actually costs time

The production pruning keeps dense 84->12->2 tensors. P100/P310/P400 differ in
active mask entries, but forward/backward and Adam still operate on the dense
shapes. A lower sparse FLOP estimate is not a proportional MATLAB runtime saving.

The supplemental unmodified one-epoch call-tree profile is separate from the
full-run timers (profiling itself slowed the loop to about 1.18 s). It shows:

- dlfeval: about 0.81 s inclusive for 48 updates.
- applyLearnableMasks: 0.177 s inclusive for 50 calls (initial, per-step, final).
- dlnetwork.set.Learnables: 0.0995 s inclusive, nested within mask reapplication.
- applyGradientMasks: 0.0522 s inclusive; adamupdate: 0.1598 s inclusive.
- Table operations among the largest exclusive costs: tabular.dotReference
  2410 calls, dotAssign 973, dotListLength 946. They also occur outside masking.

These times overlap and cannot be summed into an overall percentage. They
support investigating container/table/network-update overhead, not only the
multiplication by a binary mask. Small matrix arithmetic is only part of the
cost; the profile includes tracing, cached network execution and updates.

Also, the existing TEMP TIMING block in runDPDSweep wraps **fitSparsePNNN**, not
just fineTunePrunedNetwork. Its label explicitly includes predictions. The
separate prediction measurements above show that these are small here, though
they must be retained when comparing to the original 8297.80 s. FLOP/parameter
counts and table assembly were not separately timed and add minor unmeasured
postprocessing; no claim of exactly reproducing the old block time is made.

## Ordered proposals for a later phase

The following are experiments to test, NOT implemented or measured speedups.
The percentages are transparent scenarios: stage share times assumed fractional
reduction. They are not forecasts, and effects from different changes may overlap.

| Priority | Candidate | Conditional saving in fine-tuning | Numerical/procedure risk |
|---|---|---|---|
| 1 | Cache mask representations; reduce repeated table indexing/assignment and network Learnables resets, while still masking both gradients and weights each step | Halving the two mask stages saves 5.84%; absolute ceiling 11.67% if those stages vanished | Low-to-moderate. Cached casts can keep identical values/types; table/dlupdate rewrites must prove identical tensor ordering, masks and final learnables. Do not omit post-Adam masking. |
| 2 | Prepare normalized numeric arrays in channel-by-batch orientation once, then gather the SAME columns in the SAME randperm order and create identical CB dlarrays | Halving minibatch preparation saves 4.64%; absolute ceiling 9.28% | Low. Pure data movement can preserve samples, types, final partial batch and all arithmetic exactly. Verify isequal, including RNG state. |
| 3 | Test dlaccelerate on the existing loss/gradient function, with separate caches as needed for shapes | A 20% reduction of dlfeval saves 13.88%; a 50% reduction saves 34.70%; neither is demonstrated | Moderate for bitwise identity. Same scientific procedure is possible, but caching/fusion/backend details require exact comparison. Forward/predict are already automatically accelerated inside dlfeval, so extra benefit can be small. |
| 4 | Parallelize independent P fits from the immutable dense source, with private deterministic RNG and controlled CPU thread counts | Ideal two-worker limit: 50% of this block; actual gain unknown and may be negative | Keeps the per-P mathematical procedure if isolated correctly, but thread scheduling/reduction order can affect bitwise identity. Memory copies and 20-thread oversubscription are major constraints. |
| 5 | Inspect optimizer/container overhead or an explicit 84->12->2 implementation | Adam alone is 8.69%; halving it saves 4.35%. Manual forward/backward has a larger but unknown opportunity | High numerical risk if Adam equations, epsilon placement, casts or reduction order change. Defer until lower-risk changes are characterized. |

Hoisting the constant-per-epoch learning-rate calculation and avoiding redundant
bestNetwork bookkeeping in fixed-epochs mode could preserve the procedure, but
they are outside the timed large stages. Their direct opportunity is small
(OtherSeconds is only 0.96%); indirect copy-on-write effects are unmeasured.

Changing batch size, epoch count, learning rate, data precision, pruning schedule
or loss is NOT a procedure-preserving optimization. GPU execution and sparse or
manual kernels can change floating-point reductions and may be slower for this
small network; no GPU benefit is assumed or tested.

### Relating scenarios to the reported sweep

Only if these stage shares also describe the historical 8297.80 s block:

- Halve masking: roughly 484 s saved (8.1 min), about 5.0% of full sweep time.
- Halve minibatch preparation: roughly 385 s (6.4 min), about 4.0% of full sweep.
- Reduce dlfeval by 20%: roughly 1152 s (19.2 min), about 12.0% of full sweep.

Full-sweep fractions multiply block savings by the reported 0.861. These are
conditional Amdahl estimates, not extrapolated benchmark results or promises.
Use the unmodified warm baseline on the same machine/session when validating
any future change. Require identical weights, masks, final RNG state and
predictions for exact-preservation candidates; otherwise report differences
explicitly, even if NMSE is close.

## Reference and artifacts

MathWorks documents trace caching with dlaccelerate and warns that extra gains
may be limited when dlnetwork forward/predict already dominate:
https://www.mathworks.com/help/deeplearning/ref/dlaccelerate.html
The supported per-parameter update interface is documented here (performance
improvement is not guaranteed):
https://www.mathworks.com/help/deeplearning/ref/dlupdate.html
These are current online docs; the benchmark itself ran installed R2026a.

Raw results: `tpa0813123_e6d7_4e6d_9309_e6b0aa1de867/summary.csv`,
`stage_summary.csv`, per-minibatch CSVs, per-epoch MAT timing arrays,
`baseline_P310.mat`, `environment.mat`, and `call_tree_functions.csv`.
See README.md for the reproducible driver and removal scope. No commits/push.
