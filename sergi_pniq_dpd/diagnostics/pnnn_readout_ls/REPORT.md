# P310 mixed PNNN: one conditional output-layer LS refit

Completed 2026-11-04 in MATLAB R2026a. Exactly one real-data coefficient solve
per output was performed, as one experiment. No dense training, Adam update,
new pruning, alpha search, production change, RF access, CFR, commit or push.

## Scientific answer

Optimizing only the existing readout recovers **0.024273 dB on identification,
0.016012 dB on the development complement and 0.016842 dB on the full capture**.
The development gain fails the predeclared 0.10 dB practical threshold.
Development Q MSE improves 0.5343%, so there is no aggregate Q penalty.

The full-capture gap to PN-IQ-GMP remains **3.298167 dB**, versus 3.315009 dB
before refitting. The intervention closes 0.5081% of that dB difference and
0.7250% of the absolute MSE difference. These are distinct descriptive ratios,
not percentages of universal causal importance.

This is scenario C: conditional readout optimization is real but accounts for
very little of this frozen mixed model's gap. It rules against its final
linear readout being the main bottleneck under the fixed hidden activations,
mask, target normalization and identification data. It does not distinguish
hidden-layer optimization from representation or temporal-information limits,
and does not demonstrate a failure of Adam.

## Sources and initial state

Root branch main, HEAD 1600d268c38378ad0d4fb689e7ca64dcb438f418. No tracked or
staged changes were present. Five diagnostic directories were already untracked
and were preserved. There was no pnnn_readout_ls directory or previous LS fit.
The initial state is recorded in repository_before.json.

Paths below are relative to the repository root:

- Raw October capture:
  `results/experimentosSergi20261023/experiment20261023T102742_xy.mat`.
- Scientific source:
  `sergi_pniq_dpd/results/dpd_sweep/tpf1484cb1_eb1d_4fe1_9d7e_13899ee8f7e5/`.
  experiment.mat supplies centered x=u, y=x_ILC, configuration and partitions;
  models_P0310.mat supplies historical model/mask and PN-IQ complexity;
  pnnn_target_0310.mat and linear_sweep.mat supply frozen reference predictions.
  sweep_dense_source.mat is read only to verify normalization, never to train.
- Mixed fit:
  `sergi_pniq_dpd/diagnostics/pnnn_mixed_loss/tp390d053f_18ea_464b_8c05_db89f2b156eb/`.
  experimental.mat and protocol.mat establish its training provenance.
  The unique inference artifact was located and checked in its child directory
  `tpc6c585a5_81aa_4b4a_8ac0_0ca4c0fbcf81/inference.mat`.
  Its metrics.csv, amplitude.csv and full-precision analysis.mat supply the
  comparison reference and historical amplitude-bin verification.

The centered October raw x/y exactly match experiment.mat. No April data were
used. There are 49151 identification and 442369 complement rows, 491520 total.
No new split, normalization, gain, delay, phase adjustment or DC convention was
introduced. All five prior diagnostic reports were consulted; the closed gap
audit was not rerun. The historical and PN-IQ predictions were reused rather
than refitted. Alpha=1 was not recomputed or added to this four-model analysis.

## Frozen representation and the intervention

The source is the saved 84 -> 12 sigmoid -> 2 network, with single-precision
learnables. Masks directly confirm 273 hidden input weights, 12 hidden biases,
23 output weights and 2 output biases: 310 active scalars. The other 736
weights are exactly zero. The I readout excludes hidden neuron 7 and has 11
hidden coefficients plus bias; Q uses all 12 hidden coefficients plus bias.

The original default predict path extracts sigmoid1 activations in single.
They are not recomputed with a double sigmoid approximation. Both normalized
inputs and original normalized targets are double. The activations are promoted
to double only after extraction to form the LS design.

For c in {I,Q}, let K_c be its permitted hidden indices, N the identification
count, and A_c=[H(id,K_c),1]. Targets use the original saved muY/sigmaY:

    t_I = (Re(r.*y) - muY_I)/sigmaY_I
    t_Q = (Im(r.*y) - muY_Q)/sigmaY_Q
    L = sum_c w_c * ||A_c*beta_c - t_c(id)||^2 / (2*N)

The saved weights are 1.4177580700411294 and 0.5822419299588707. Each is a
positive constant multiplying its own independent quadratic problem, so
gradient_c=(w_c/N)*A_c'*(A_c*beta_c-t_c) vanishes at the same minimizer for
any positive w_c. No weighted variant, alpha optimization or Ridge is needed.

For each output the helper computes an economy SVD A=U*S*V', fixes
tau=max(size(A))*eps(s_max), and solves beta=V_r*((U_r'*t)./s_r). The rank rule
was declared before fitting and uses identification only. No A'*A system was
formed to solve. All singular values were retained:

| Design | I | Q |
|---|---:|---:|
| Shape | 49151 x 12 | 49151 x 13 |
| Effective rank | 12 | 13 |
| Rank threshold | 2.79391088e-9 | 2.79391088e-9 |
| Largest singular value | 424.602064 | 455.815072 |
| Smallest singular value | 3.354462 | 3.312213 |
| Raw condition number | 126.578296 | 137.616489 |
| Column-L2-scaled condition | 166.937141 | 180.505823 |

The permitted coefficients are independently identifiable at this tolerance;
the small gain is not caused by discarding ill-conditioned directions. Column
scaling is used only for a diagnostic condition number, not another fit.
The two real solves, diagnostics and model update took 0.460405 s in this run
(20 reported MATLAB threads); this excludes preflight, IO and evaluation.

All 25 readout coefficients changed. They were cast back to single and inserted
only at permitted positions. Hidden weights, hidden biases, actual extracted
activations, graph, feature configuration, normalization, masks and state were
checked unchanged. All 310 active entries remain nonzero, all 736 pruned
weights remain zero, and the RNG state is unchanged by the real fit.

## Optimality and precision

| Maximum absolute normal-equation cosine | I | Q |
|---|---:|---:|
| Original readout, frozen native activations | 0.02732357 | 0.02401082 |
| Double LS solution | 6.7058e-14 | 4.0098e-13 |
| Rounded coefficients, double accumulation | 9.4983e-7 | 6.5562e-7 |
| Actual stored-network normalized inference | 8.2235e-7 | 6.4150e-7 |

Cosine is abs(a_j'*e)/(norm(a_j)*norm(e)), without centering. Target-scaled
normal-equation residuals and gradient norms are also saved in ls_diagnostics.csv
and saved_verification.json. The double solution satisfies stationarity; its
single realization shows the expected small rounding residual.

Maximum coefficient rounding is 5.8188e-8 (I) and 5.5225e-8 (Q), with relative
L2 errors 2.2219e-8 and 1.8548e-8. On the full restored complex waveform,
coefficient casting alone changes relative L2 by 1.4953e-8. Actual network
inference versus ideal double readout has relative L2 6.6256e-8 and maximum
absolute difference 1.4342e-8. Full NMSE is:

- Double readout over frozen native activations: -35.577318614384 dB.
- Rounded coefficients with double accumulation: -35.577318668560 dB.
- Actual saved single-network inference: -35.577318717399 dB.

The actual-versus-ideal NMSE difference is about 1.03e-7 dB, far smaller than
the observed 0.016842 dB improvement. Precision does not account for the small
scientific gain. The new model's prediction after MAT reload equals its saved
prediction bit for bit. It is deliberately not equal to the old model's output.

Direct normalized identification loss drops from 0.00144614138301684 to
0.00143661111575075. The checked forward-rounding budget is 1.74129e-8 in
loss units, versus an actual reduction about 9.53027e-6. Both identification
component losses decrease. Physical-waveform-derived losses below differ from
these direct normalized values at about 1e-10 due to finite-precision output
denormalization and phase restoration, not a different objective or dataset.

## Comparative results

All metrics below use actual saved predictions, not ideal double LS outputs.
NMSE is complex error energy relative to target energy. Physical I/Q errors
are components of r.*(prediction-y); normalized MSE divides by saved sigmaY^2.
Magnitude RMSE uses abs(prediction)-abs(y). Angular RMSE uses wrapped
angle(prediction.*conj(y)), weighted by abs(y)^2, and is expressed in degrees.
These are offline ILC-imitation metrics, not RF EVM or ACPR.

| Model | Identification NMSE dB | Development complement dB | Full capture dB |
|---|---:|---:|---:|
| Historical PNNN | -35.111657 | -35.130808 | -35.128892 |
| Mixed PNNN | -35.527836 | -35.564112 | -35.560477 |
| Mixed PNNN + readout LS | -35.552110 | -35.580124 | -35.577319 |
| PN-IQ-GMP | -39.060027 | -38.855492 | -38.875485 |

| LS change versus mixed | Identification | Development | Full |
|---|---:|---:|---:|
| NMSE improvement, dB | 0.024273 | 0.016012 | 0.016842 |
| Total MSE change, % | -0.557350 | -0.368002 | -0.387049 |
| Physical I MSE change, % | -0.482119 | -0.308051 | -0.325562 |
| Physical Q MSE change, % | -0.766113 | -0.534302 | -0.557615 |
| Mixed loss change, % | -0.659006 | -0.448993 | -0.470116 |

| Full-capture metric | Historical | Mixed | Mixed + LS | PN-IQ |
|---|---:|---:|---:|---:|
| Physical I MSE | 1.398468e-7 | 1.205033e-7 | 1.201110e-7 | 5.412609e-8 |
| Physical Q MSE | 4.122536e-8 | 4.343986e-8 | 4.319763e-8 | 2.229134e-8 |
| Normalized I MSE | 8.875469e-4 | 7.647819e-4 | 7.622921e-4 | 3.435147e-4 |
| Normalized Q MSE | 2.919699e-3 | 3.076536e-3 | 3.059381e-3 | 1.578737e-3 |
| Mixed loss | 1.479149e-3 | 1.437782e-3 | 1.431023e-3 | 7.031138e-4 |
| Complex MAE | 2.979580e-4 | 2.833914e-4 | 2.837301e-4 | 1.811314e-4 |
| Magnitude RMSE | 3.739331e-4 | 3.485930e-4 | 3.483420e-4 | 2.391954e-4 |
| Angular RMSE, degrees | 0.478547 | 0.485378 | 0.482756 | 0.327097 |
| RMS, native units | 0.024280766 | 0.024280683 | 0.024289149 | 0.024286927 |
| PAPR before CFR, dB | 13.879753 | 13.903841 | 13.924538 | 14.809420 |

The LS gain is not uniform across metrics: complex MAE worsens 0.1195% on the
full capture and magnitude MAE also increases (2.178694e-4 -> 2.184256e-4).
Magnitude RMSE improves only 0.0720%; angular RMSE improves 0.5403%.
Full RMS rises 0.03487% and PAPR 0.020697 dB. These waveform observations are
not transmission authorization or RF safety certification.

Identification is the optimized domain; development improvement is empirical,
not guaranteed by LS. The practical criterion fails solely because 0.016012 dB
is below 0.10 dB; Q decreases rather than exceeding the permitted +10%.
No variant was selected or refitted to pass the criterion.

## Amplitude distribution

The same ten equal-count input-amplitude bins (49152 samples each) were reused.
Their boundaries and counts match the full-precision historical MAT table
exactly, and their mixed baseline MSE matches the previous results.

| Decile | NMSE gain dB | Physical I change % | Physical Q change % |
|---|---:|---:|---:|
| 1 | 0.140751 | -3.771322 | -0.538228 |
| 2 | -0.018034 | 0.930504 | -1.199624 |
| 3 | 0.017853 | -0.270143 | -0.796423 |
| 4 | -0.002968 | -0.468730 | 1.341122 |
| 5 | -0.020695 | -0.160274 | 2.109048 |
| 6 | -0.046911 | 0.962148 | 1.419110 |
| 7 | -0.033914 | 0.732472 | 0.908541 |
| 8 | 0.035487 | -2.090906 | 1.987948 |
| 9 | 0.014290 | -1.209633 | 1.445193 |
| 10 | 0.015941 | 0.167798 | -1.904508 |

Five bins improve total MSE and five worsen. The lowest-amplitude bin supplies
61.567% of net recovered error energy, and the highest supplies 49.873%; their
sum exceeds 100% because deterioration elsewhere offsets some benefit. The
largest local total-MSE increase is 1.086% in decile 6. Q worsens in deciles
4..9, peaking at +2.109%, while improving overall. A favorable single decile
does not satisfy the predeclared whole-complement practical criterion.
No additional temporal/spectral analysis or figure was warranted by this result.

## Complexity and limits

All four models have 310 active real parameters. All three neural variants
retain historical 780 ideal sparse arithmetic operations/sample, the same
12 sigmoid evaluations, and the same feature and normalization path. LS adds
no inference operation. Actual dense execution is not guaranteed to skip zeros;
the historical dense-matrix core count is 2252. PN-IQ reports 1013 analytic
operations/sample under its repository convention. These counts exclude some
special-operation/scaling costs and are not equal-latency or memory claims.

All data are previously used development data. Full-record DC removal,
periodic memory and correlated identification/complement samples remain part
of the historical procedure. There is no independent capture, confidence
interval, newly measured PA response, generalization result or universal
architecture comparison. Readout optimality is conditional on this hidden
matrix and mask; it does not establish global neural optimality.

## One recommended next experiment, not executed

Run one controlled **hidden-layer-only continuation starting from this saved
LS model**, keeping its output weights/biases fixed. Preserve the 84 inputs,
12 sigmoids, all masks, normalization, partitions, alpha=0.5 and active budget.
Use the historical fixed 164-epoch Adam schedule and minibatch/seed protocol
without a hyperparameter search; only permitted W1 and b1 entries may update.
Compare against the frozen LS starting point and PN-IQ with the same metrics.

This tests whether changing the hidden mapping can recover useful error with
the existing inputs and architecture, after removing the final-readout
stationarity deficit. A material identification/development gain would show
recoverable hidden-optimization room for this endpoint. A small or adverse
result would remain inconclusive about intrinsic capacity because the output
is frozen and the optimization budget is finite. It would not prove that
future-envelope information is the cause. No such continuation or alternative
experiment is implemented or scheduled here.

## Artifacts and integrity

One run directory: `tp927d59fa_d1a5_4040_a786_7820557ca62f/`.

- prepared.mat: validated frozen feature cache, identification/complement
  indices, original model/prediction, targets, settings and preflight checks.
  Its roughly 341 MB avoids rebuilding the input features between stages.
- fit_started.mat: persistent one-fit guard.
- readout_model.mat: independent adjusted model, double and rounded coefficient
  solutions, singular values, masks, source provenance, RNG and timing.
- inference.mat: actual new prediction and numerical/invariance checks.
- metrics.csv, deltas_vs_mixed.csv: four-model comparison and LS changes.
- amplitude.csv, amplitude_deltas.csv: shared bins and local effects.
- ls_diagnostics.csv, readout_coefficients.csv: rank/conditioning, stationarity,
  all 25 coefficient changes and precision effects.
- analysis.mat: tables, bin-order indices, decision and analytical FLOPs.
- saved_verification.json and logs: serialization, guards and detailed checks.

The first analysis attempt stopped at an inappropriate bitwise comparison
against decimal CSV boundaries. The existing MAT table resolved this without
changing any bin or scientific result; the CSV rounding difference was
4.85723e-17. Only analysis resumed, using the already saved LS model. The fit
was not repeated. VALIDATION.md records the distinction and tolerances.

All 612 protected pre-existing files have unchanged SHA-256 hashes. The before
and after manifests are identical. The original gap-audit directory and all
earlier diagnostics are untouched. Root HEAD/branch and tracked/staged files
remain unchanged; only this new diagnostic directory joins the five existing
untracked ones. No commit or push was performed.
