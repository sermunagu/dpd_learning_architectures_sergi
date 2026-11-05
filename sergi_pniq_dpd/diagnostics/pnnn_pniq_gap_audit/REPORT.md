# P310 PNNN versus PN-IQ-GMP: frozen-model scientific audit

Completed 2026-11-04. No model training, coefficient fitting, model edits,
production changes, CFR, RF access, commits or pushes were performed.
All new work is isolated in this directory.

## Conclusion

The audit establishes **different structured representations and different
optimization procedures** as the leading hypotheses to investigate, without
isolating their causal contributions or establishing an intrinsic failure of
neural networks. The active-parameter budget does not
make these function classes equivalent. PN-IQ uses explicit carrier/envelope
interactions, some future-envelope information and phase-dependent auxiliaries;
the PNNN must learn its mapping through 12 shared sigmoid activations.

There is also direct evidence of incomplete conditional output optimization:
the mixed PNNN readout has nonzero identification gradients, while PN-IQ's
saved least-squares coefficients nearly satisfy their normal equations.
This does NOT quantify how much of the 3.315 dB gap output optimization can
recover. The residual correlations and structural differences do not isolate
a causal contribution of any one feature, lag or auxiliary.

The most informative next experiment is **one least-squares refit of only
the existing PNNN output layer, freezing all hidden weights/features and
the complete pruning mask**. It isolates readout optimization without adding
neurons, inputs or parameters. It is proposed below, not executed.

## Audit provenance and scope

The prior loss experiment, loss validation and mixed-loss reports, scripts,
CSV files and saved models were inspected. Numerical conclusions below also
use direct model/checkpoint inspection and recomputation, not only those reports.

Original source under `sergi_pniq_dpd/`:
`results/dpd_sweep/tpf1484cb1_eb1d_4fe1_9d7e_13899ee8f7e5/` contains
`experiment.mat`, `models_P0310.mat`, `sweep_dense_source.mat` and
`linear_sweep.mat`. Mixed PNNN is loaded from
`diagnostics/pnnn_mixed_loss/tp390d053f_18ea_464b_8c05_db89f2b156eb/tpc6c585a5_81aa_4b4a_8ac0_0ca4c0fbcf81/inference.mat`.

Both compared predictions were reconstructed from frozen model parameters
and agree exactly with saved predictions. Original dense inference was
recomputed as a diagnostic reference, not retrained. Masks match the historical
P310 mask. The common centered arrays map x=u to y=x_ILC from
`experiment20261023T102742_xy.mat`, sampled at 491.52 MHz.
There are 49151 identification and 442369 development-complement samples,
491520 total. No gain/phase/delay correction or normalization was fitted here.

The input and target retain the original full-record DC-removal convention.
PNNN uses saved z-scores and inverse phase rotation; PN-IQ uses saved
peak-normalization factors already absorbed into inference coefficients.
The complement has informed development before. Neither the full record nor
its complement is an independent test. The previous inventory found no valid
untouched compatible capture; that search was not repeated.

## Representations: same budget, different functions

Let r[n]=conj(x[n])/abs(x[n]), with r=1 at zero. Both models restore the
output phase with conj(r[n]). Their remaining structures differ substantially.

| Property | PNNN alpha=0.5 | Frozen PN-IQ-GMP P310 |
|---|---|---|
| Input representation | Re/Im of 14 rotated taps, plus 14 envelope values at each power 1,3,5,7: 84 features | 155 selected real columns from 129 complex/auxiliary descriptors |
| Nonlinearity | 12 learned sigmoids of sparse affine combinations; nonlinear interactions are implicit | Explicit carrier times delayed envelope powers; real or imaginary components |
| I/Q outputs | Shared 12 hidden activations, separate sparse linear readouts | Shared 155 selected columns, 155 separately fitted coefficients per output |
| Active allocation | 273 input weights + 12 hidden biases + 23 output weights + 2 output biases | 155 I coefficients + 155 Q coefficients |
| Memory in actual model | Current and past taps n through n-13 | Carrier lags 0..10; envelope lags -2..11 |
| Scaling | Per-feature and per-output z-score from identification | Column peak and one target peak during fit; folded into saved coefficients |
| Arithmetic precision | Learnables single, original feature/data path preserved | Saved coefficients double |
| Historical arithmetic count | 780 ideal sparse operations/sample; dense execution accounting 2252 | 1013 operations/sample |

PN-IQ has 152 canonical columns and 3 auxiliaries; 98 selected columns are
real parts and 57 imaginary parts. Canonical selected polynomial degrees
range from 1 to 10 (not merely the configuration's maximum candidate degree).
100 canonical columns combine a carrier and an envelope at different lags.
11 use envelopes at n+1 or n+2. These are not available explicitly in PNNN's
past-only feature vector. At this sampling rate, PNNN's history spans about
26.45 ns; PN-IQ's two-sample envelope look-ahead is about 4.07 ns.
Periodic indexing is used by both; negative lag means a future sample, not
a longer past memory. Candidate configuration limits Qpmax/Qnmax=50 and
Pmax=13 must not be confused with the actual selected support.

A canonical PN-IQ feature is Re or Im of

    r[n] * x[n-l] * product_j abs(x[n-m_j])^p_j.

This directly expresses envelope-dependent memory interactions useful for a
DPD/ILC-imitation mapping. PNNN contains rotated tap values and envelope
powers separately; it must synthesize their products through sigmoids and
linear combinations. Its lack of explicit eighth/ninth envelope powers is
not a theorem that it cannot approximate them. Likewise, a band-limited
input makes future and past samples correlated: missing look-ahead is an
information-set difference, not yet proof of an irreducible prediction gap.

The three noncanonical columns are the real/imaginary components of the
conjugate auxiliary and the imaginary component of the envelope-only auxiliary.
In rotated coordinates they involve r*conj(x) and r*abs(x). Unlike canonical
phase-normalized features, they retain absolute-phase dependence. Ideal PNNN
features are invariant to a common input phase rotation, making its restored
mapping equivariant. PN-IQ can represent additional symmetry-breaking behavior.
This is a structural observation, not proof of hardware IQ imbalance or of
the auxiliaries' causal importance. No auxiliary was removed or refitted.

The two models BOTH share features across I/Q; the contrast is 12 learned
shared activations versus 155 selected explicit columns, not sharing versus
no sharing. Model/support selection and dense pretraining also introduce
inductive choices not summarized by the final 310 active scalars.

### Surviving neural connections

Hidden neurons retain 16..30 input weights each; none is disconnected.
Neuron 7 has no I-output weight, while all 12 feed Q: I has 11 hidden weights
plus bias, Q has 12 plus bias. Feature-group surviving weights are:
52 real-tap, 49 imaginary-tap, 37 envelope^1, 58 envelope^3,
46 envelope^5 and 31 envelope^7 weights, totaling 273.
Eleven raw features have no surviving connection: 10,12,15,53,56,70,79,80,81,83,84.
Feature 15 is the theoretically zero current imaginary tap; its numerical
normalization issue cannot directly affect this masked P310.

For the mixed model, the largest per-neuron fraction outside sigmoid
[0.01,0.99] is 1.6644%; activation standard deviations are 0.08386..0.19198.
There is no evidence here for widespread dead/saturated units as the dominant
failure. Rare tail saturation and subtler conditioning remain possible.

### Operation-count caveat

The historical 780 assumes a kernel skipping zero weights; current dense
matrix inference does not automatically achieve that sparse runtime. The
repository reports nonlinear operations separately (12 sigmoid evaluations,
14 magnitudes/square roots, phase divisions). The count is not complete
wall-clock cost: the explicit z-score transformations also require arithmetic
not itemized in that historical core schedule. PN-IQ uses polynomial feature
construction and two 155-term dot products, without sigmoids. No inference
runtime benchmark was run. Equal parameters do not mean equal operations.

Memory and latency are separate questions as well. The neural implementation
stores dense learnable arrays including pruned zeros, normalization statistics
and activations; PN-IQ stores its coefficients, support/descriptor metadata
and feature buffers. Single versus double precision and block temporaries also
affect storage. No peak-memory or end-to-end latency measurement is available.
An exact streaming implementation of the selected look-ahead terms would need
future samples (up to two samples of buffering/alignment delay); the offline
periodic record already supplies them. The 4.07 ns look-ahead is not a measured
implementation latency or an RF real-time performance claim.

## Optimization audit

PNNN first selects dense/fine-tune durations on the internal split, discards
that provisional network, reinitializes with seed 42 and refits dense on all
identification samples. Global magnitude pruning then removes 736 of 1032
weights while protecting all 14 biases. Each fine-tune resets Adam moments,
uses seed 100042, masks gradients and restores zero weights after updates.
The mixed loss uses exactly the historical durations and mask, with alpha=0.5.

The saved dense epoch is 1223. Applying the source budget-scaling code to
the saved configuration gives maximum 1260 epochs and a 42-epoch learning-rate
drop period. The selected dense epoch is close to the budget cap. The selected
fine-tune duration, 164, equals its scaled cap. This is compatible with a
budget-limited optimization trajectory but does not prove that loss was still
decreasing monotonically, or that more epochs would improve development.

Dense initial LR is 2e-4 with factor 0.95; its nominal last-epoch LR is about
4.519e-5. Fine-tuning restarts at 2e-4 and ends at 1.71475e-4 (drops every
41 epochs). Thus the fine-tune ends at a relatively high step size rather
than annealing near zero. There are 7872 minibatch updates. That schedule
can leave stochastic/nonstationary error, but its causal cost was not tested.

**Loss trajectories are unavailable.** The saved dense source contains only
denseFit, bestDenseEpoch, fineTuneEpochs and runtimeConfig. DenseFit contains
network and normalization. The dense selectionInfo history is not serialized;
the final dense trainnet info is not retained. The pruning helper returns
network/masks/counts/bestEpoch, not per-epoch losses or Adam moments. Existing
profiling epoch arrays record timing, not the historical scientific loss curve.
No convergence curves were fabricated from endpoint losses or unrelated runs.
No repeated seed exists for this mixed-loss comparison, so initialization
sensitivity is plausible for the nonconvex procedure but not measured.

PN-IQ selects a shared sparse support with DOMP on identification and then
solves I and Q independently with peak-scaled, minimum-norm least squares,
lambda=0. It does not perform nonlinear gradient descent over its coefficients.
It also does not prove globally optimal support: DOMP is a greedy search.

### Conditional stationarity, without taking a training step

With hidden features fixed, define A as the allowed hidden activations plus
bias for one output, e_z as its normalized residual and w_c its mixed weight.
The mixed-loss readout gradient is w_c*A'*e_z/N. We only evaluated this
expression; no linear solve or weight update was performed.

| Identification diagnostic | PNNN I | PNNN Q |
|---|---:|---:|
| Allowed readout coefficients including bias | 12 | 13 |
| Maximum abs normal-equation cosine | 0.0273235 | 0.0240108 |
| Mixed-loss readout gradient L2 | 0.00111704 | 0.000545498 |
| Column-L2-scaled readout condition number | 166.94 | 180.51 |

Cosine = (a_j'*e)/(norm(a_j)*norm(e)); it includes the bias and is not centered
Pearson correlation. PN-IQ's corresponding maximum absolute cosines are
8.31e-10 and 2.84e-9. Its peak-scaled design condition number is 1.34e8,
so coefficients/individual term contributions should not be treated as stable
causal importance scores, despite the small normal-equation residual.

Neural stationarity uses a double-precision evaluation of the stored single
weights, with full-prediction relative L2 difference 8.34e-8 from production
inference. The derivative formula was checked synthetically to 4.78e-12.
The result supports nonstationarity of the smooth stored network's readout,
not a quantified NMSE recovery or full-network convergence diagnosis.
It does not demonstrate that Adam failed: finite-budget stochastic updates
need not end at the conditional least-squares optimum. The saved gradients
describe the double surrogate, not bit-exact single-precision training
derivatives; the mixed weights are positive constants in either precision.

## Frozen error comparison

| Full development capture | Mixed PNNN | PN-IQ-GMP |
|---|---:|---:|
| Complex NMSE, dB | -35.560477 | -38.875485 |
| Physical rotated I MSE | 1.205033e-7 | 5.412609e-8 |
| Physical rotated Q MSE | 4.343986e-8 | 2.229134e-8 |
| Total physical MSE | 1.639431e-7 | 7.641742e-8 |
| Complex MAE | 2.833914e-4 | 1.811314e-4 |
| Exact magnitude RMSE | 3.485930e-4 | 2.391954e-4 |
| Reference-energy-weighted angular RMSE, degrees | 0.485378 | 0.327097 |

NMSE uses 10*log10(sum(abs(p-y)^2)/sum(abs(y)^2)); I/Q use r*(p-y).
Magnitude error is abs(p)-abs(y); angular error is angle(p*conj(y)), squared
and weighted by abs(y)^2 before averaging. These are ILC imitation metrics.
Rotated Q is not exactly target-relative phase error. No RF EVM/ACPR is inferred.

PN-IQ lowers total MSE 53.3878%, I MSE 55.0833%, and Q MSE 48.6846%.
I accounts for 75.8374% of the absolute MSE advantage, Q for 24.1626%.
Its gap is already 3.53219 dB on identification and remains 3.29138 dB on
the development complement. This is not a discrepancy appearing only outside
the fit rows; neither fact proves an intrinsic capacity ceiling.

### Where is the advantage?

- All ten common input-amplitude deciles favor PN-IQ. The advantage ranges
  from 8.46143 dB in the first decile to 2.41584 dB in the highest decile.
  The top decile supplies 42.1045% of the total absolute MSE difference.
  Therefore high-amplitude errors matter but do not explain the whole gap.
- The ten bins of abs(y-x), a descriptive ILC-correction proxy, also all favor
  PN-IQ (2.45287..7.14000 dB). This proxy includes linear gain/phase differences
  and is NOT a pure PA nonlinearity/compression measure. The current mapping
  alone cannot assign physical compression states to the PA.
- All 16 consecutive 30720-sample blocks favor PN-IQ by 3.16601..3.56971 dB.
  These blocks are 62.5 us at the saved rate. There is no isolated time region
  explaining the gap or evidence of sustained drift within this 1 ms record.
  This is waveform time, not training time or a long-term stability test.
- Complex residual lag-1 autocorrelation magnitudes are 0.46292 (PNNN) and
  0.53996 (PN-IQ); at lag 5 they are 0.02473 and 0.03385. Both are structured,
  and lower MSE does not require lower normalized autocorrelation. The two
  centered complex residual sequences have correlation magnitude 0.63418.

### Correlations with nonlinear memory features

Only development-complement rows are used for centered Pearson correlations;
no coefficients were fitted. The strongest selected-basis Q example is
Im(r*x[n-1])*abs(x[n])^8: rho=-0.21355 with PNNN Q error versus +0.01164
with PN-IQ Q error. A look-ahead term Im(r*x[n-1])*abs(x[n+1])^8 gives
-0.20496 versus +0.02164. The simple future envelope abs(x[n+2])^7 has
Q correlation +0.13681 for PNNN and -0.00055 for PN-IQ.

The conjugate-Q auxiliary correlates with PNNN I/Q errors at +0.09099/+0.08447,
versus -0.01886/-0.03006 for PN-IQ. These observations support residual
structure aligned with interactions and symmetry-breaking columns available
to PN-IQ. They do not measure unique explanatory power: features are highly
correlated, lags are correlated in the waveform, and the largest correlations
were inspected among many candidates. No causal fraction of the gap follows.
Near-zero theoretical channels can yield undefined/roundoff-sensitive
correlations and must not be interpreted as physical evidence.

### Spectral error, not RF linearization

The valid aligned full-record residual e=p-y permits a discrete spectrum.
Power per FFT bin is abs(FFT(e))^2/N^2; its sum equals physical MSE (Parseval
checked within 1e-12 relative). Frequency resolution is 1 kHz. The plotted
PSD is averaged over 60 bins; band powers use unsmoothed bins.

| Absolute-frequency band | PNNN residual power | PN-IQ residual power | PN-IQ advantage |
|---|---:|---:|---:|
| 0..48.6 MHz | 7.6166e-8 | 3.9284e-8 | 2.87548 dB |
| 48.6..100 MHz | 4.0238e-8 | 1.9575e-8 | 3.12939 dB |
| 100..245.76 MHz | 4.7539e-8 | 1.7559e-8 | 4.32556 dB |

The first boundary uses the nominal 97.2 MHz occupied waveform bandwidth;
the second is a descriptive diagnostic boundary, not an ACPR definition.
PN-IQ reduces error across all bands, particularly high-frequency residuals.
This is the spectrum of differences between PA-input waveforms, not the
spectrum of a newly measured PA output. It establishes no RF linearization gain.

## Hypothesis assessment

| Hypothesis | Supporting evidence | Counterevidence / unresolved point | Assessment |
|---|---|---|---|
| A. Insufficient neural representation | 12 learned shared activations versus 155 structured columns; coherent nonlinear residuals | Neural output not conditionally optimized; no best achievable hidden representation measured | Plausible, not established |
| B. Incomplete/suboptimal optimization | Nonzero readout gradients; fine-tune selected at budget cap; limited LR decay | No loss curves/moments or replicated initialization; unknown recoverable NMSE | Direct evidence for conditional nonstationarity, plausible contributor |
| C. Harmful pruning | 736 removed weights and 11 disconnected input features | Recomputed dense NMSE -35.572399 is already 3.303086 dB behind PN-IQ; mixed sparse is only 0.011922 dB worse than that dense endpoint | Cannot explain the pre-existing dense gap; causal pruning contribution unresolved |
| D. Inadequate inputs | No future envelope or absolute-phase auxiliaries; explicit product features absent | Past samples may predict future information; nonlinear products can be approximated implicitly | Concrete input/class differences, effect unisolated |
| E. PN-IQ structural advantage | Explicit cross-lag products, orders through 10, separate linear least-squares readouts and small normal-equation residuals | Greedy support not globally optimal; auxiliary/look-ahead contribution not isolated | Strongest descriptive support, joint with optimization |
| F. Other | Different output-loss weights explain part of historical gap; scaling/conditioning affect both optimizers | Mixed loss improves only 0.432 dB; PN-IQ still wins both components and all loss definitions; predictions/preprocessing verified | Loss contributes, not a complete explanation; no preprocessing mismatch demonstrated |

The dense/sparse comparison changes training objectives and trajectories;
the 0.011922 dB difference is NOT a causal pruning estimate. Generalized sigmoid
saturation, disconnected whole neurons and channel-15 inference noise have
little support as dominant explanations for this mixed P310.

## One proposed experiment, not executed

**Conditional readout least-squares refit of the frozen mixed PNNN.**

Freeze its 273 input weights, 12 hidden biases, feature processing, phase
convention, normalization, architecture and all masks. Change only the method
used to fit the existing output coefficients: solve the two linear readout
problems on identification rows, with the existing absent I connection kept
exactly zero. There are 12 allowed I coefficients including bias and 13 Q
coefficients including bias: 25 output parameters, unchanged total budget.
Do not modify hidden activations, add features, continue Adam or tune alpha.

For output c, let K_c contain only the mask-permitted hidden indices and let
A_c=[H(id,K_c),1]. Use the saved target normalization:
t_I=(Re(r*y)-muY_I)/sigmaY_I and t_Q=(Im(r*y)-muY_Q)/sigmaY_Q, restricted
to the original identification rows. The two conditional problems are

    L_c(beta_c) = w_c/(2*N_id) * ||A_c*beta_c - t_c||_2^2
    gradient_c = w_c/N_id * A_c' * (A_c*beta_c - t_c)
    beta_c_star = pinv(A_c) * t_c

These are mathematical definitions, not an implemented or executed refit.
I excludes hidden neuron 7, Q retains all 12, and both include the existing
bias. Map coefficients back only to those positions; all mask-forbidden
entries stay exactly zero. No new parameter is permitted. If a permitted
coefficient happens to become zero, report the actual nonzero count rather
than forcing it nonzero to keep a nominal count of 310.

Extract H through the unchanged hidden forward path and its original
inference precision, then promote those fixed activations for the linear
solve. Do not substitute the audit's double hidden-layer surrogate, recompute
normalization, or change the feature path during this proposed experiment.
Use the fixed alpha=0.5 objective and the deterministic double-precision
SVD rank threshold max(size(A_c))*eps(s_max(A_c)), derived only from the
identification design. There is no regularization or threshold search.
Report the rank and any truncation. Positive per-output weights are constants, so
for frozen hidden features the two unconstrained least-squares solutions are
independent of those constant weights; this is not an extra loss experiment.
Use the original single-precision inference format after solving and check
normal-equation residuals and numerical effects of coefficient casting.
In exact arithmetic without rank truncation, each identification component's
MSE cannot increase because the old readout is a feasible solution. This
guarantee does not extend to development, coefficient casting, or arbitrary
rank truncation; their actual effects must be reported.

Controls: unchanged mixed PNNN and frozen PN-IQ. Metrics fixed before fitting:
identification/development complex NMSE, physical I/Q MSE, mixed objective,
angular and magnitude RMSE, amplitude bins, RMS/PAPR, mask/parameter integrity
and normal-equation cosines. A practical predeclared materiality criterion is
>=0.10 dB development NMSE gain with <=10% Q-MSE increase relative to mixed
PNNN; report all outcomes even if it fails. These are engineering thresholds,
not statistical significance. Training loss should not increase beyond a
documented rounding budget; otherwise diagnose solver/casting problems rather
than launching more variants.

Interpretation must remain conditional:

- Improvement on identification and development quantifies a recoverable
  readout-optimization component without changing representation.
- Identification-only improvement raises generalization/conditioning concerns
  within development and does not justify adoption.
- Little improvement rules against the final readout being the major bottleneck;
  it does NOT distinguish insufficient hidden representation from poor hidden
  optimization or missing look-ahead/phase information.

No independent capture enters fitting, tolerance tuning or selection. A later
untouched compatible capture remains necessary for external confirmation.
This single small experiment is more discriminating now than adding neurons,
altering memory and optimizer together, or running another alpha sweep.

## Artifacts and integrity

Authoritative corrected basis inspection:
`tp22743bea_bfe0_448b_bf54_ec7980ccb1c6/pniq_basis.csv` and inspection.log.
The earlier inspection directory is retained; its generic degree formula
counted an extra carrier for the envelope-only auxiliary and is superseded
for that one metadata field. No model or scientific prediction was affected.

Main analysis: `tp7d131b74_614e_4611_8771_7807054f30c4/`, containing metrics,
amplitude/correction/temporal tables, residual autocorrelation, spectral power,
basis/lag correlations, connections, neurons, readout stationarity, audit.mat,
audit.log and residuals.png. `summary.log` records supplemental checks.
Code: inspectModels.m, auditGap.m and finishAudit.m.

All 583 manifest-protected original files retain identical SHA-256 hashes,
including the prior experiments and their documentation. The continuation
completed this previously pending check: `integrity_after.csv` has the same
schema, paths and row order as `integrity_before.csv`; `integrity_summary.json`
records 583 matches, zero missing/unreadable files and zero differences.
The earlier draft asserted this result before the final manifest existed;
that evidence gap is now closed. See `CLOSURE.md` for the continuation review.
Root tracked files
and HEAD are unchanged. Only this new diagnostic directory was added to the
pre-existing untracked diagnostics. No fit, production integration, commit
or push was performed.
