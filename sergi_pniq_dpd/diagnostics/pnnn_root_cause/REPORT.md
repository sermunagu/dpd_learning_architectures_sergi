# PNNN scientific and technical root-cause audit

Started 2026-11-03; continued 2026-11-04 without rerunning the full audit.
Initial commit: `1600d268c38378ad0d4fb689e7ca64dcb438f418`.
Initial root status: `## main...origin/main`, clean. All new work is confined
to this directory. No training, hardware access, production changes or Git
mutations were performed. The nested research repository retains its prior
local commit; this audit does not modify its history.

## Main finding (measured)

Most of the October gap exists in the **dense network already**. Pruning plus
the historical fine-tuning adds 0.443507 dB of degradation, whereas the dense
network is 3.303086 dB behind PN-IQ-GMP. These are comparisons of final saved
models, not an isolated causal decomposition of pruning and optimization.
The total P310 gap is 3.746593 dB = 3.303086 + 0.443507 dB. Approximately
88.16% of that dB difference is already present in the dense result; this
arithmetic partition is not a percentage of causality or of error energy.

All four predictions below use the identical 491520-sample centered October
input/ILC target, with 49151 identification and 442369 evaluation samples:

| Model | Full NMSE dB | Identification | Evaluation |
|---|---:|---:|---:|
| GMP-DOMP P310 | -38.415477 | -38.552254 | -38.400569 |
| PN-IQ-GMP P310 | -38.875485 | -39.060027 | -38.855492 |
| PNNN dense, 1046 parameters | -35.572399 | -35.544369 | -35.575519 |
| PNNN P310 | -35.128892 | -35.111657 | -35.130808 |

The dense model is a capacity/optimization diagnostic, not a fair P310-budget
competitor. Similar identification/evaluation errors do not indicate obvious
memorization, but these correlated subsets of one record cannot establish
generalization to independent captures.

## Mathematical reconstruction and source references

Paths below are relative to `sergi_pniq_dpd/`; line numbers refer to the
unmodified source in the initial commit.

1. `DPD/runDPDSweep.m:26` loads x=u and y=x_ILC; lines 34-41 remove their
   full-record DC and construct the split. This is ILC imitation, not PA
   forward modeling. `toolbox/splits/buildCommonComparisonSplit.m:11` calls
   `toolbox/pn_gmp_comparison/selectPeakSegment.m:4`, which chooses a contiguous
   10% segment around the TARGET peak. The internal split is 85/15%, balanced
   across ten target-amplitude bins with seed 42. Evaluation is its complement,
   not an independent RF test. Full-record DC and periodic memory also cross
   subset boundaries; do not call this a strict untouched holdout.
2. Let r[n]=conj(x[n])/abs(x[n]), with r=1 at exact zero, and
   v_m[n]=r[n]x[(n-m) mod N], m=0,...,13. The 84-vector is
   f=[Re(v_0:13), Im(v_0:13), |x_0:13|, |x_0:13|^3,
   |x_0:13|^5, |x_0:13|^7]. Targets are t=[Re(r*y),Im(r*y)]. See
   `toolbox/pnnn/buildPhaseNormDataset.m:29` and `:39` (feature ordering),
   `:79` (target). Phase division is based on the current input, not each tap.
3. `toolbox/pnnn/trainDensePNNN.m:141` computes feature/target means and sample
   standard deviations on the relevant training rows. Only an EXACTLY zero
   standard deviation is replaced by one. Define z=(f-muX)/sigmaX and
   q=(t-muY)/sigmaY, componentwise. Selection statistics use internal train;
   definitive statistics are recomputed on all identification rows (`:86`).
4. `trainDensePNNN.m:132` constructs 84 -> FC(12) -> sigmoid -> FC(2), with
   linear outputs. Thus a=Wz+b, h=1/(1+exp(-a)), qhat=Vh+c. Parameter count is
   84*12+12+12*2+2=1046 (1032 weights, 14 biases). Actual saved layer shapes
   and counts agree (`layers.csv`). There is no explicit identity/residual
   path. Twelve shared sigmoid responses must reconstruct both rotated target
   components, including the dominant through-signal. Finite sigmoid mixtures
   are bounded; unrestricted amplitude extrapolation is not guaranteed.
5. `trainDensePNNN.m:37` selects dense epochs using Adam, MSE, seed 42,
   minibatches 1024, shuffle every epoch, initial rate 2e-4 and factor .95.
   Historical update counts are converted to epoch budgets (`:151`), with
   floor/ceil distinctions. Fine-tuning duration is selected on the provisional
   sparse reference P200 (`:63`), not independently per final P. The provisional
   model is discarded, the seed reset, and a definitive dense model trained
   from scratch on identification for the selected epoch count (`:78-101`).
   The saved October durations are 1223 dense and 164 fine-tuning epochs.
   Keeping epochs fixed while the training subset grows changes update count;
   the final refit has no saved independent early-stopping validation.
6. `toolbox/pnnn/pruneAndFineTunePNNN.m:61` globally ranks the absolute weights
   of both layers, drops the smallest, and protects all biases. Each budget
   starts from the same dense source. For P310, 736 weights are masked and
   296 weights plus 14 biases remain. Fine-tuning resets RNG to 100042 (`:40`),
   shuffles via randperm each epoch (`:130`), masks gradients, applies Adam,
   then reapplies the mask (`:140-147`). There are 48 batches/epoch, 7872 updates.
   The integrated acceleration only changes loss execution in fixed-epoch mode
   (`:122`); default is false, and epoch selection stays historical.
7. `toolbox/pnnn/fitSparsePNNN.m:9` takes the saved durations/statistics and
   records the inference model. `toolbox/pnnn/predictPNNN.m:4` implements
   yhat=conj(r)*[(sigmaY_I*qhat_I+muY_I)+i*(sigmaY_Q*qhat_Q+muY_Q)].
   `toolbox/sweep/applyDPDModels.m:13-29` centers the incoming full record,
   uses the stored statistics, and restores phase; it does not restore target
   DC. No refitting occurs. Real features are double; learnables and neural
   prediction arithmetic are single. Energy metrics explicitly cast to double.

This function is phase-referenced nonlinear regression of the complete ILC
signal. Mathematical equivariance is qualified by floating-point channel 15
and the special handling of exact zero, rather than being assumed bitwise.

## Provenance and available evidence

`inventory.csv` reads source provenance from each saved experiment, rather
than inferring capture identity from folder creation dates:

| Folder under results/dpd_sweep | Capture | Availability |
|---|---|---|
| tp10cf25e9_6429_492f_a1f9_18eb4eb5f157 | April 29 x->x_ILC | Dense and four points (20,100,200,340) |
| tp98e6f7ac_f3cd_44c7_9ce3_fd8619319748 | April 29 x->x_ILC | Dense and all 49 P20:10:500 points |
| tpf1484cb1_eb1d_4fe1_9d7e_13899ee8f7e5 | October 23 x->x_ILC | Dense and all 49 points; analyzed here |
| tpf25d5828_f737_4914_9d00_ffdcb309de89 | October 23 | Experiment only; no dense or sparse point |

April forward-PA captures and `results/parameter_sweep` checkpoints also exist;
they are not used as October DPD evidence. Acceleration diagnostics dated
November reuse the October source and are not new RF campaigns. The saved
October provenance points at the old root `results/experiment..._xy.mat`;
the copy now under root `results/experimentosSergi20261023/` was verified
sample-for-sample after the same DC removal, for both input and target.

The actual measured file `experiment20261023T102742_DPD_offline_comparison.mat`
was read. Its pre-CFR `meas_out.x` imitation errors against RAW `_xy.y` are
-38.413494, -38.872918 and -35.126410 dB. Recorded RF errors are -39.551646,
-40.165922 and -36.493678 dB. These reproduce the task's values. They are
reported separately from centered checkpoint inference; their small numerical
differences must not be labeled model regression. RF NMSE uses the tutor's
normalized measured waveform convention, not the same imitation target.
The identical ILC reference produces a finite approximately -3101 dB in the
helper because of its realmin floor, not a physical noise measurement.

## Features, activations and pruning (measured)

The current real tap (feature 1) and first envelope (29) are analytically
identical and have correlation 1; both retain connections (9 and 11).
Identification z-score matrix numerical rank is 83, not 84. This numerical
rank includes channel 15 rounding noise: the ideal mathematical features have
both a duplicate and a zero, so their independent dimension is at most 82.
Adjacent delayed quadratures correlate up to .9856 (16/17); fifth/seventh
envelope powers correlate about .968. `correlations.csv` lists |rho|>.95;
correlation does not alone prove nonlinear redundancy or uselessness.

Feature 15 has std 8.0194e-19 and max normalized magnitude 8.65: normalization
amplifies arithmetic residue. In contrast, seventh-power feature 71 has std
2.8882e-10 and max |z|=19.60: its small raw scale is physically expected and
its normalized tails remain large. A generic tiny-variance cutoff would mix
these two very different cases. Features 71 and 84 have the same envelope
range but different retained connectivity (12 versus 0), showing that tap
position matters. All 84 channel statistics and singular values are saved.

P310 retains 273/1008 input weights (27.08%) and 23/24 output weights (95.83%).
Every hidden neuron has 16-30 active inputs and at least one output. Eleven
features have no surviving input weights, including 15; no neuron is completely
disconnected. The final maximum weights are .6163 in fc1 and 2.1983 in fcOut.
Global magnitude pruning strongly favors output retention, but input/output
weights have different roles and magnitudes are not sensitivity measures.
This allocation is evidence to investigate, not proof of an incorrect mask.

Saturation is defined as h<.01 or h>.99, evaluated with the literal threshold
|a|>4.59511985 (rounded log(99)); .001/.999 uses |a|>6.90675478 (rounded
log(999)). These exact code thresholds are retained. No neuron exceeds 1.805% saturated samples in
the dense model or 1.661% in P310. P310 activation standard deviations range
.0869-.1975; mean sigmoid derivatives range .1463-.2289 (maximum possible .25).
Average saturation over all neuron/sample pairs is .4528% dense and .4084%
P310. No hidden unit is almost constant by these measures. `OutputWeightedSensitivity`
is ||V(:,j)|| times the mean sigmoid derivative: a normalized-output local
proxy, not the full physical Jacobian or a causal importance score. Broad
sigmoid saturation is not supported as the dominant explanation. Rare tail
saturation remains possible; an error-conditioned activation study is pending.

## Error distribution (measured)

Deciles use identical ranked sample indices per input/target amplitude for
all models. They have equal counts; table columns include amplitude limits,
MSE, MAE, within-bin NMSE, total error share and target-energy share. Domain 1
means input amplitude and domain 2 means target amplitude.

For input amplitude, the highest decile contributes 66.86%, 64.81%, 50.81% and
58.01% of error for GMP, PN-IQ, P310 and dense, respectively. P310's lower
percentage is NOT better: its highest-decile MSE is 9.20e-7 versus PN-IQ's
4.95e-7. In the lowest decile, P310 MSE is 1.47e-7 versus 1.75e-8 for PN-IQ,
an absolute as well as normalized gap. Low-decile NMSE is -22.96 versus
-32.20 dB, but low target energy magnifies the normalized interpretation.
The middle fifth decile also has excess P310 MSE (8.01e-8 versus 2.64e-8).
The problem is not confined to a few high peaks or low-energy bins.

Target-amplitude highest-decile error shares are similar: 66.86%, 64.87%,
50.97%, 58.01%. Worst 1% of samples by error contribute 38.92%, 38.92%,
32.63%, 41.34%; worst 0.1% contribute 13.21%, 13.41%, 12.23%, 19.67%.
These independently sorted sets quantify concentration, not identical events.
Across 20 consecutive equal-length blocks, P310 NMSE spans -35.44 to -34.89,
PN-IQ -39.25 to -38.58, and dense -36.08 to -35.25 dB. The deficit persists
throughout the record; this does not establish absence of shorter transients.

## Loss mismatch (mathematically exact; causal effect unproven)

For rotated physical error e_r=r*(yhat-y), the implemented loss is

`L = mean(e_r,I^2 / sigmaY_I^2 + e_r,Q^2 / sigmaY_Q^2) / 2`.

Complex NMSE instead uses `sum(e_r,I^2+e_r,Q^2)/sum(abs(y)^2)`; phase rotation
preserves this energy. Target centering cancels in errors. Thus minimizers
coincide automatically only when the two sigmas are equal (or special model
constraints happen to give the same optimum). Here sigmaY_I=.01255251 and
sigmaY_Q=.003757623, giving Q/I physical squared-error weight ratio **11.15925**.
The continuation read the checkpoint directly again: sigmaI =
0.0125525119001017 and sigmaQ = 0.00375762280052252. The physical coefficients
are wI=1/(2*sigmaI^2), wQ=1/(2*sigmaQ^2), hence
wQ/wI=(sigmaI/sigmaQ)^2=11.1592477280154. This is NOT a claim that normalized
Q receives eleven times the normalized-I coefficient: both normalized squared
errors have coefficient 1/2. It is the conversion back to physical units that
produces the unequal coefficients.
The weighting applies in the input-aligned frame, not fixed laboratory I/Q.
It may trade larger radial error for better quadrature accuracy. This is a
plausible mechanism, not proof it caused the measured gap; no alternative
loss was optimized in this task. Supplemental measured components are:

| Model | Radial MSE | Quadrature MSE | Normalized loss, full record |
|---|---:|---:|---:|
| GMP | 5.6020e-8 | 2.8936e-8 | .0012024 |
| PN-IQ | 5.4126e-8 | 2.2291e-8 | .00096113 |
| P310 | 1.3985e-7 | 4.1225e-8 | .0019036 |
| Dense | 1.2585e-7 | 3.7640e-8 | .0017323 |

PN-IQ beats both neural models in BOTH components and even under the neural
loss on these full-record samples. Consequently, weighting alone is not an
inevitable explanation for the gap: representation and/or optimization remain
the primary unresolved category. A weighting experiment is attractive because
it is inexpensive and controlled, not because causality is proven.
Normalization is applied consistently at
inference, so this is an objective choice rather than a denormalization bug.

## Prior evidence reconciled

The October mask has zero connections from channel 15, as did the April P310.
Its direct influence on these sparse predictions is therefore zero. The older
phase report initially called structural-zero training pending; the later
`docs/GUIA_REPOSITORIO_DPD.md:90` and existing experiment
`results/pnnn_phase_experiment/tp1bfa4378_d472_497b_87d7_b5c638c34392/comparison.csv`
show it WAS subsequently executed on April data. Evaluation improves only
.042929 dB, with dense/fine-tuning epochs 1221/163 versus 1228/164. This weakens
the hypothesis that this one channel explains the multi-dB gap. It does not
isolate the training trajectory effect in October. Four other saved comparison
files are synthetic P20, two-epoch tests, not real corrected P310 evidence.

`docs/DPD_EFFICIENCY_ANALYSIS.md:1` is April data: its no-PNNN global Pareto
frontier must not be relabeled October. Its P310 ideal sparse 780 FLOPs require
a sparse kernel; stored dense matrices imply 2252 core operations in its
accounting plus activation/special operations. Active parameter count is not
runtime cost. The November acceleration reports establish 1.87x stable speedup
and tiny numerical differences, not improved approximation. These differences
are orders of magnitude too small to account for the present multi-dB deficit.

## Prioritized hypotheses and next experiments (proposals, NOT executed)

Scientific priority differs from the cost of the next experiment:

1. **Representation/capacity and optimization: joint highest priority, high
   causal uncertainty.** The dense model already has most of the gap and
   PN-IQ beats its two physical error components and weighted loss. Twelve
   nonlinear basis responses may be insufficient, or the optimizer may not
   find a sufficiently good solution. Neither can be separated with one
   trained network. Another seed probes optimization sensitivity; controlled
   width or residual comparisons probe representation but also change training.
2. **Loss formulation: exact mismatch, medium priority, high causal uncertainty.**
   The physical weighting is proven, its damage is not. PN-IQ's lower weighted
   loss contradicts treating that weighting as an unavoidable accuracy ceiling.
3. **Pruning: measured secondary net penalty, uncertain allocation optimality.**
   The .4435 dB difference includes fine-tuning. An alternative mask comparison
   can investigate allocation, but cannot explain the prior dense deficit.
4. **Feature redundancy/scaling: proven properties, uncertain causal impact.**
   Duplication and correlated channels may affect conditioning; channel 15 has
   no direct P310 path. April's small correction effect weakens a dominant-cause
   claim without excluding an October training-trajectory effect.
5. **General sigmoid saturation: low priority as dominant cause.** The measured
   rates, derivatives and connected units oppose it. Sigmoid representation
   limits and rare error-conditioned tail saturation remain separate questions.

The following catalogue retains evidence and possible tests; its row order is
not a claim that the first hypothesis is the demonstrated or most likely cause.

| Hypothesis | Supporting evidence | Counterevidence / unknown | Minimum discriminating experiment and cost |
|---|---|---|---|
| Objective weighting limits complex NMSE | 11.16x Q weighting; dense already behind; low/middle amplitude absolute error | A different loss optimum and its I/Q tradeoff have not been measured | Fixed original P310 initialization/mask/seed/164 epochs, change ONLY to physically weighted complex MSE; one new fine-tune against exact saved control, or two fits for a fresh paired control |
| Small sigmoid basis/optimization limit | 1046-param dense still 3.30 dB behind; only 12 shared nonlinear responses; no residual path | A trained network is not the best representable function; no saved final optimizer history proves convergence | First another seed at unchanged architecture: one complete selection/refit pipeline plus P310; then a separately controlled width comparison if needed |
| Dense optimization not converged or epoch transfer suboptimal | Single seed; duration selected on provisional/internal model and P200; new refit differs in sample count | No large train/evaluation gap; 1223 epochs alone neither proves nor disproves convergence | Continue a diagnostic copy of dense with fixed loss and report both subsets; one continuation, but reset Adam moments would confound a true continuation if optimizer state unavailable |
| Pruning allocation is suboptimal | 27% fc1 retained vs 96% outputs; .4435 dB net degradation | Most gap predates pruning; no dead neurons; no causal feature importance | One alternative-mask P310 fine-tune from the same dense with all other settings fixed; report global magnitude control and mask budgets |
| Redundant/noisy/scaled features | Duplicate 1/29, channel15 noise, correlated delays/powers, large normalized tails | Z-score handles ordinary scale; channel15 disconnected in P310; April fix only .043 dB | Inspect frozen sensitivities first (zero trainings); feature redesign requires one fresh selection/refit pipeline and P310 |
| Sigmoid saturation dominates | Rare tail saturation exists | <1.81% per-neuron saturation, healthy mean derivatives and activation variation | Error-conditioned activations with saved models, zero trainings; do not switch activation on current evidence |
| Residual architecture helps | No identity path; full target must be reconstructed even where correction is small | No demonstrated benefit; residual scaling changes weighting and small input does not ensure small correction | Separate controlled model yhat=x+correction, or yhat=g*x+correction with g fixed from identification; one new selection/refit pipeline plus P310 and matched budget, with physical loss fixed consistently |

Recommended first authorized intervention: the paired fixed-mask P310 loss
experiment. It uses the existing dense source, costs no dense retraining,
tests an exact identified mismatch, and preserves architecture/seed/epochs.
Use full, identification and evaluation NMSE plus radial/quadrature errors,
and keep RF validation separate. A null result would not rule out objective
effects during dense training, but would inform whether a more expensive
paired dense-loss experiment is justified. No experiment is authorized by
this report itself and no accuracy improvement is promised.

### Single next experiment specification (not implemented or executed)

Hypothesis: at the fixed P310 mask and starting weights, the historical unequal
physical I/Q weighting limits attainable complex NMSE under the 164-epoch
procedure. This tests a fine-tuning intervention, not the cause of the entire
dense-network gap.

Change only the loss in an isolated experimental copy. If normalized residuals
are dI and dQ, compare historical `mean(dI.^2+dQ.^2)/2` with
`mean(sigmaI^2*dI.^2+sigmaQ^2*dQ.^2)/(sigmaI^2+sigmaQ^2)`.
The latter is proportional to physical complex MSE; its normalized-component
coefficients sum to one, avoiding an arbitrary overall shrinkage of gradients.
Keep the stored sigmas fixed. This scaling choice must be recorded because
Adam with finite epsilon is not exactly invariant to scaling the objective.

Start from the SAME original dense source with the SAME P310 mask applied,
not from the already fine-tuned final P310 network. Preserve all 84 features,
normalization, twelve sigmoid units, 310 active parameters, protected biases,
seed 100042, permutations, 1024 batch size, 164 epochs, learning-rate schedule,
fresh Adam moments and original nonaccelerated execution. Do not select new
epochs, adjust learning rate, or change loss weights after seeing results.

Cost: one new experimental fine-tune and zero dense fits, using the previously
verified exact original P310 checkpoint as control. If initialization/config
provenance cannot be established, add one original-control fit (two total)
before attributing a difference to the intervention. GMP and PN-IQ are frozen
reference predictions, not refitted competitors. A second seed would be a
later replication rather than part of this minimum experiment.

Predeclare full/identification/development complex NMSE, absolute radial and
quadrature MSE, both loss definitions, the existing amplitude bins and error
concentration. Verify exact masks, zero entries, count and RNG; weights are
expected to differ. Report every metric, including unfavorable bins.

Suggested decision rule to register BEFORE training: a decrease of at least
0.10 dB in identification NMSE AND the same-capture development complement
supports a material benefit of this intervention for this seed/source. The
0.10 dB is an engineering decision threshold, not a statistical significance
level. Smaller consistent improvement is weak evidence; changes below 1e-4
dB are numerically negligible for this decision. No benefit or a tradeoff
rejects a material benefit of this fixed-duration intervention, not all possible
effects of the loss during dense training. Interpret actual training loss and
convergence before attributing a null result to intrinsic model capacity.

The existing complement has already informed model analysis/selection and
must be called a development set. Freeze the proposal and all thresholds now;
do not search additional variants on it and then call it an independent test.
Any claim beyond this capture requires a separate, untouched capture after
the choice is locked, and a subsequent independently authorized RF experiment.

A residual model is deferred because it changes target representation,
normalization and potentially useful capacity, and needs a new dense pipeline.
A width/activation change also confounds representation with optimization and
costs a fresh pipeline. Neither has stronger causal evidence at present than
the inexpensive, precisely specified loss intervention.

## Supplemental reference checks

Completed `verifyExtras.m` output is in
`tp5a080fb0_4cba_4bf2_ad94_e39144b14241/`. PN-IQ reconstructed predictions
match the saved linear checkpoint exactly. GMP differs by maximum absolute
1.49552e-12, relative L2 8.10499e-12, and NMSE 1.42109e-12 dB. Exact identity
is not claimed. This is compatible with floating-point effects in inference
versus stored fitting predictions; the precise operation responsible was not
isolated. A first supplementary attempt stopped on an overly strict assumed
1e-12 relative threshold. The final script records the measured discrepancy
instead of hiding it or treating the aborted run as a successful test.

Against measured pre-CFR signals, bundle inference relative differences are
4.14353e-11 (GMP), 4.45643e-11 (PN-IQ), and 7.82547e-7 (PNNN); the maximum
PNNN absolute difference is 4.74086e-7. Thus the measurement file and this
checkpoint are numerically close, but not bitwise identical. Exact export/
rounding/scaling provenance is unresolved. RF metrics are taken from the
actual measurement file, never attributed to a newly reconstructed waveform.

The April phase report also found its dense network slightly worse than its
fine-tuned P310; this differs from October's .4435 dB net pruning penalty.
That is another reason not to pool captures or infer universal pruning damage.

See VALIDATION.md for executed assertions, reproducibility and limitations.

## Reference verification closed on 2026-11-04

Only the missing reference summary was computed, with `verifyExtras(true)`;
the full feature/activation/error audit and prior results were not regenerated.
Evidence: `tpe4a4c804_5b22_4e47_b722_3de03b117090/reference_metrics.csv`.

| Quantity | GMP-DOMP P310 | PN-IQ-GMP P310 |
|---|---:|---:|
| Exact equality | No | Yes |
| Maximum absolute error | 1.49551967509386e-12 | 0 |
| Relative L2 | 8.10499362085407e-12 | 0 |
| Maximum error / maximum reference magnitude | 1.09411893797394e-11 | 0 |
| Saved-prediction NMSE dB | -38.4154774055449 | -38.8754853637991 |
| Reconstructed NMSE dB | -38.4154774055435 | -38.8754853637991 |
| Absolute NMSE difference dB | 1.4210854715202e-12 | 0 |

The diagnostic error budgets fixed before this completion run were <1e-9
for both global relative measures and <1e-8 dB for NMSE change. These are
conservative numerical budgets, respectively 10000 times tighter than the
earlier scientific prediction-L2 and NMSE tolerances (1e-5 and 1e-4 dB), not
statistical confidence limits or a promise of bitwise reproducibility.
Both references pass. Scaling by the global maximum avoids near-zero sample
division. GMP's discrepancy cannot explain a several-dB neural deficit and
requires no production inference modification. Its exact floating-point
origin is not required to close this scientific-equivalence check.

The requested read-only audit is complete. Causal separation of representation,
optimization and loss, independent-capture generalization and RF confirmation
remain future experiments, not evidence supplied by this audit. The small
measured-versus-checkpoint PNNN difference retains the provenance limitation
already stated above.
