# P310 conditional hidden-layer continuation

Completed in MATLAB R2026a on 2026-11-04. One real continuation was run.
All new files are confined to this diagnostic directory. Production, earlier
experiments, hardware and CFR were not modified or invoked.

The final model improves development-complement NMSE by **0.290993619 dB**
relative to the saved mixed + LS model and reduces physical Q MSE by
**3.541719976%**. It meets both predeclared descriptive criteria (gain at least
0.10 dB; Q MSE increase at most 10%). This is evidence of additional conditional
optimization room in the hidden layer from this particular starting point.
It is not evidence of independent generalization or an architectural limit.

## Sources and reproducibility

The starting checkpoint is
`../pnnn_readout_ls/tp927d59fa_d1a5_4040_a786_7820557ca62f/readout_model.mat`.
Its `inference.mat` was reproduced exactly. Its `prepared.mat` supplied the
stored normalized 84-column features, two normalized targets, phase rotation,
identification/complement indices, original mixed prediction and native hidden
activations. Features and normalization statistics were not regenerated.

The saved mixed protocol comes from
`../pnnn_mixed_loss/tp390d053f_18ea_464b_8c05_db89f2b156eb/protocol.mat`.
It points to the original permutation/RNG reference in
`../pnnn_loss_experiment/tp15ee449b_7a1a_4442_a6ae_cdefa2453e8a/protocol.mat`.
The source experiment and existing PN-IQ prediction belong to October sweep
`../../results/dpd_sweep/tpf1484cb1_eb1d_4fe1_9d7e_13899ee8f7e5/`.
The underlying capture is `experiment20261023T102742_xy.mat`, not an April
capture. Centered original input/target arrays matched the saved experiment
exactly. The earlier gap/root-cause and readout audits supplied provenance and
metric conventions; none of their fits was repeated.

The successful run is
`tp1442baa6_833f_4abe_a213_602d50180629/` (called RUN below).
`RUN/final_model.mat` contains the final model, training trace/Adam states/RNG
and full provenance. `RUN/inference.mat` stores its prediction and invariants.
All CSVs and logs referenced below are in RUN. Exact source paths and settings
are also readable in `saved_verification.json`.

The first preflight attempt, `tpbe2d718e_3f6d_4545_b190_decc46f0547d/`, stopped
while reading an absent `optimizer` field from the compact runtime config.
No gradient diagnosis or update had run. The reader was corrected to obtain
optimizer, shuffle and CPU metadata from the saved October experiment config;
numeric training settings still come from the original mixed protocol. The
failed log is retained. This was a metadata-schema assumption, not conflicting
scientific provenance. The subsequent preflight passed before training.

## Initial gradient diagnosis

All 49,151 identification rows were evaluated in natural order, in batches of
1,024. Native forward/AD used single learnables and double CB data. Batch means
and gradients were accumulated in double with sample-count weights, including
the final 1,023 rows. The exact same convention was used at both endpoints.

Initial native mixed loss was 0.001436611181188806. Its difference from the
previous saved normalized LS loss was 6.54e-11 (gate: 1e-7).

| Initial gradient group | L2 norm |
|---|---:|
| Active fc1 weights | 2.831604237e-3 |
| All 12 fc1 biases | 1.127381885e-4 |
| Combined permitted hidden parameters | 2.833847641e-3 |
| Pruned fc1 weights, raw gradient | 5.924208647e-3 |
| Permitted output weights and biases | 6.862471636e-8 |
| Excluded output connection, raw gradient | 4.640540178e-5 |

Active hidden-weight absolute magnitudes have mean 1.244190614e-4, median
9.172189085e-5, P95 3.626656578e-4 and maximum 6.984113740e-4. The largest
active hidden-neuron norm is approximately 1.39739e-3 (neuron 8), the smallest
3.57749e-4 (neuron 7). Complete active/pruned/all and per-neuron statistics are
in `gradient_before.csv` and `gradient_neurons_before.csv`.

The allowed output gradient is below the predeclared 1e-5 gate, consistent
with the constrained LS solution at single precision. Its one excluded
connection need not be stationary. Raw gradients at pruned coordinates are
reported only diagnostically; they never authorize an update.

Six deterministic finite differences checked the first active weight and bias
of neurons 1, 6 and 12. A temporary double copy avoided differencing rounded
single losses; step size was eps(double)^(1/3)*max(1,abs(parameter)). Maximum
absolute FD-versus-double-AD error was 8.00109e-13; versus native AD it was
1.37976e-9. Native/double normalized predictions differed by relative L2
1.64260e-7, below 1e-6. All per-array native/double AD checks passed. This
validates the smooth derivative of the stored parameters, not a bitwise
derivative of quantized single arithmetic. The real fit retained its original
precision. Diagnosis preserved network values/state, masks, normalization and
RNG. Nonzero gradients alone are not evidence of bad training.

## Synthetic validation and the single real fit

A deterministic 3->4->2 synthetic network with unequal output masks and 1,027
rows exercised the same worker for two epochs (four updates). Direct versus
helper mixed-loss error was exactly zero. Its raw output-gradient norm was
0.270864683, yet output values remained exact, demonstrating an effective
freeze. Only allowed hidden parameters changed; pruned zeros, batch orders,
RNG and finite predictions passed. The historical schedule boundaries were
also checked. The synthetic test restored its caller RNG.

The real network stayed 84->12 sigmoid->2, with 310 active parameters:
273 hidden weights, 12 hidden biases, 23 output weights and 2 output biases.
Only the first 285 were trainable in this continuation.

| Setting | Value |
|---|---|
| Epochs / updates | 164 / 7,872 (48 batches per epoch) |
| Identification / complement / full rows | 49,151 / 442,369 / 491,520 |
| RNG / shuffle | Twister, seed 100042, historical randperm every epoch |
| Minibatch size | 1,024; final batch 1,023 |
| Learning rate | 2e-4 * 0.95^floor((epoch-1)/41) |
| Four 41-epoch rate blocks | 0.0002, 0.00019, 0.0001805, 0.000171475 |
| Optimizer | Original adamupdate call; beta1=0.9, beta2=0.999, epsilon=1e-8 |
| Adam initialization | New empty first/second moments; iteration zero |
| Loss weights, alpha=0.5 | [1.4177580700411294, 0.5822419299588707] |
| Precision / execution | Single learnables; stored double CB data; CPU; no dlaccelerate |
| Measured worker duration | 93.8098897 s, including checks/checkpoint writes |

This was a new optimization phase, not restoration of the original optimizer
state. Every epoch permutation matched its stored historical counterpart;
the final RNG matched the original expected state exactly. Epoch 164 was
retained without development-based selection. `training_started.mat` and
global guards prevent repeating the real fit through the supplied entry point.

All 7,872 updates checked exact fcOut equality *before* remasking. Masks and
736 pruned zeros stayed exact. Every epoch retained 310 nonzero active
parameters. The 273 active hidden weights and all 12 biases changed; their
change L2 norms were 0.362229576 and 0.217772569, with maxima 0.091550462 and
0.110440254. Output changes were exactly zero. Frozen/pruned Adam moments
were also zero. Saved checkpoints at epochs 41/82/123 (1,968/3,936/5,904
updates) passed the same stored invariants. Final saved inference was reloaded
and reproduced exactly. A separate uint32 typecast comparison confirmed
identical IEEE-754 output weight/bias bit patterns, including signed zeros,
at all three checkpoints and the final model (`output_bit_verification.json`).
No training was repeated for these verifications.

`training_epochs.csv` records rates, cumulative updates, timing and online
sample-weighted minibatch loss. That loss uses changing parameters and is not
a frozen end-of-epoch objective. Timing is descriptive, not a speed benchmark.

## Prediction comparison

NMSE uses complex physical error divided by physical target energy. Physical
I/Q MSE follows the earlier input-rotated coordinate convention
r=conj(x)/abs(x) (r=1 at zero), not fixed laboratory axes. Mixed loss is
(wI*MSEI/sigmaYI^2 + wQ*MSEQ/sigmaYQ^2)/2 with the unchanged training scales.
MAE is mean absolute complex error. Phase error is target-energy-weighted
wrapped angular RMSE. RMS and PAPR refer to the predicted waveform before CFR.

| Model | Identification NMSE (dB) | Development complement (dB) | Full capture (dB) |
|---|---:|---:|---:|
| Mixed alpha=0.5 | -35.527836 | -35.564112 | -35.560477 |
| Mixed + readout LS | -35.552110 | -35.580124 | -35.577319 |
| Hidden-only continuation | **-35.869448** | **-35.871117** | **-35.870951** |
| PN-IQ-GMP | -39.060027 | -38.855492 | -38.875485 |

| Model | Identification mixed loss | Complement mixed loss | Full mixed loss |
|---|---:|---:|---:|
| Mixed alpha=0.5 | 0.001446141265 | 0.001436853241 | 0.001437782024 |
| Mixed + readout LS | 0.001436611101 | 0.001430401874 | 0.001431022784 |
| Hidden-only continuation | 0.001363251592 | 0.001358157013 | 0.001358666460 |
| PN-IQ-GMP | 0.000681740505 | 0.000705488514 | 0.000703113761 |

These prediction-derived double metrics and the native batched diagnostic
loss have different reduction paths; their tiny differences are recorded,
not substituted silently. The native final identification loss is
0.001363251602981805.

Relative to LS, identification/complement/full NMSE gains are respectively
0.317338351 / 0.290993619 / 0.293631931 dB. Complement mixed loss decreases
5.05067%, I MSE decreases 7.53798%, and Q MSE decreases 3.54172%. Both
channels improve, rather than trading Q for the overall gain.

| Full-capture quantity | LS before | Hidden continuation after | Change |
|---|---:|---:|---:|
| Physical I MSE | 1.201109703e-7 | 1.109434395e-7 | -7.63255% |
| Physical Q MSE | 4.319763002e-8 | 4.168865488e-8 | -3.49319% |
| Total MSE | 1.633086004e-7 | 1.526320944e-7 | -6.53763% |
| Complex MAE | 2.837300613e-4 | 2.701521764e-4 | -4.78549% |
| Magnitude RMSE | 3.483419767e-4 | 3.354473995e-4 | -3.70170% |
| Weighted angular RMSE (degrees) | 0.482755526 | 0.471772214 | -2.27513% |
| RMS | 0.024289149406 | 0.024288888725 | -0.00107324% |
| PAPR (dB) | 13.924537542 | 13.907324702 | -0.01721284 dB |

Not every summary improves: full rotated I bias increases from 3.65879e-6
to 7.45262e-6 and mean magnitude bias from 7.34881e-7 to 5.44962e-6, even
though I MSE and magnitude RMSE decrease. All four variants and all three
domains, including biases and normalized I/Q errors, are in `metrics.csv`.
PN-IQ-GMP remains better by 2.984375 dB on the complement and 3.004535 dB
on the full capture. Neither it nor GMP was refitted.

The same stored amplitude order and decile boundaries were reused. All ten
deciles improve total, I and Q MSE, MAE, magnitude RMSE and weighted phase
RMSE. NMSE gains by ascending amplitude decile are:

| Decile | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Gain (dB) | .28915 | .56134 | .55992 | .52337 | .47033 | .48967 | .49749 | .46606 | .37685 | .15550 |

The highest-amplitude decile improves least: total MSE -3.51708%, I -4.08751%,
Q -1.83991%. Its share of remaining squared error rises from 52.6969% to
54.3999% because other deciles improve more. This is not an increase in its
absolute error. See `amplitude.csv` and `amplitude_deltas.csv`; previously
saved mixed/PN-IQ decile references remain in the preceding readout-LS
`amplitude.csv`, without duplicate inference or fitting.

## Hidden activations, endpoint gradients and complexity

`activations.csv` provides each neuron's mean/std/min/max, nearest-rank
P01/P05/median/P95/P99 and fractions below .01 or above .99 in all three
domains, before and after. Full-capture neuron means span 0.188455..0.775878
before and 0.189502..0.788477 after; standard deviations span
0.083860..0.191985 before and 0.078720..0.197615 after. The largest absolute
mean shift is neuron 9, 0.315117 -> 0.294657. Averaging the tail fractions
over all 12 neurons gives 0.392049% -> 0.390811%. The largest per-neuron
tail fraction is neuron 6, 1.664429% -> 1.656901%. These thresholds describe
activation tails, not proof that a neuron is unusable or an explanation of
the performance gap. There is no aggregate saturation collapse in these
summaries; the changes are neuron dependent.

| Identification endpoint, same convention | Initial LS | Final continuation |
|---|---:|---:|
| Native mixed loss | 0.001436611181 | 0.001363251603 |
| Active hidden gradient L2 | 0.002833847641 | 0.004094171302 |
| Pruned hidden raw gradient L2 | 0.005924208647 | 0.005616203904 |
| Permitted output raw gradient L2 | 6.862471636e-8 | 0.001055792024 |
| Excluded output raw gradient L2 | 4.640540178e-5 | 0.000545725667 |

The hidden gradient norm increases despite lower loss. There is no claim
of stationarity or convergence: a fixed-duration stochastic Adam endpoint
need not have smaller gradient norm in a nonlinear problem. Nor is this
alone a failure of Adam. The formerly LS-optimal output is no longer at a
conditional stationary point after its hidden features change; it remained
frozen throughout as required. Full per-neuron endpoint tables are retained.

Masks, architecture and the 310 active inference parameters are unchanged;
736 weights remain pruned (735 hidden, one output). The inherited ideal
sparse analytic cost stays **780 FLOPs/sample**, versus **1,013** for PN-IQ-GMP.
Dense execution remains 2,252 ordinary operations: 2,064 in the affine layers
and 188 in the inherited feature/phase arithmetic schedule. Sigmoid and other
special operations retain their separate counts. These are the earlier accounting
conventions, not measured execution cost or proof of faster deployment.

## Integrity, interpretation and next task

Branch remains `main`, HEAD `1600d268c38378ad0d4fb689e7ca64dcb438f418`.
All **645 protected pre-existing files** match their initial SHA-256 hashes.
The six executable/analysis MATLAB files plus PROTOCOL fixed before training
also match their pretraining hashes. `verifyHiddenResult.m` and
`verifyHiddenBits.m` were added only for post-run validation. Git has no
tracked or staged changes; its only
additional untracked directory is this one, alongside the six previously
untracked diagnostic directories. No commit or push was made. See the
integrity/code manifests and repository snapshots. `VALIDATION.md` gives
checks, tolerances and the three harmless static-analysis style messages.

This is one seed, one saved representation, one fixed output layer and 164
additional epochs. The extra optimization budget is not matched to the
earlier baselines. All partitions belong to the same development capture,
with temporally related samples; the complement is not an independent RF
experiment. The criteria are descriptive, not statistical significance.
No independent generalization, RF improvement, intrinsic capacity limit,
causal Adam deficiency or missing-leading-feature explanation is established.

**One recommended next task, not executed:** perform a single masked LS
readout refit on the newly obtained final hidden activations, keeping this
final hidden layer, original identification rows, masks and normalization
fixed. The now-nonstationary permitted output gradient motivates measuring
the cost of having frozen the readout. This would be a different conditional
problem from TAREA 03, whose hidden features were different. Its gain or
development behavior is not guaranteed. No further training or refit has
been run as part of this task.
