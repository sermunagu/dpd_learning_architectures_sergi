# One controlled P310 mixed-loss fine-tune: alpha = 0.5

Completed 2026-11-04. One new real fine-tune, 164 fixed epochs, no acceleration.
Production, previous diagnostics and historical models were not edited.
No dense training, alpha/seed sweep, architecture change, CFR or RF operation
was performed. No commits or pushes.

## Scientific decision

Alpha=0.5 provides a useful intermediate tradeoff on the development capture.
It passes the interpretation rule locked in PROTOCOL.md before training:
on the development complement, NMSE improves **0.433304 dB** and physical
Q MSE increases **5.35814%**, against thresholds >=0.10 dB and <=10%.
Those thresholds are engineering preferences, not statistical or RF limits.

The mixed fit improves full-capture NMSE by 0.431585 dB, reduces total
physical MSE by 9.45978%, and increases Q MSE by 5.37169%. It retains 65.7349%
of alpha=1's physical-MSE reduction while removing 74.7132% of alpha=1's
extra Q penalty. This is not dominance: historical has lower Q/angle error,
and alpha=1 has lower total MSE. The mixed point is an attractive compromise
among the observed neural fits, not a proven optimum over alpha.

**Recommendation:** retain alpha=0.5 as the balanced frozen neural reference,
but stop tuning alpha on this capture for now. Prioritize studying the
PNNN/PN-IQ-GMP representation and optimization differences, alongside obtaining
untouched compatible data. The remaining PN-IQ advantage is 3.315009 dB and
holds for both I and Q. Loss choice matters, but these results do not explain
away the main neural deficit. A broad mixed-loss search has lower immediate
scientific value than understanding that remaining gap. No follow-up was run.

## Sources and fixed protocol

All project-relative paths below start at `sergi_pniq_dpd/`.

- October capture: repository-root
  `results/experimentosSergi20261023/experiment20261023T102742_xy.mat`.
- Immutable sweep source:
  `results/dpd_sweep/tpf1484cb1_eb1d_4fe1_9d7e_13899ee8f7e5/`:
  `experiment.mat`, `sweep_dense_source.mat`, `pnnn_target_0310.mat`,
  `linear_sweep.mat`.
- Alpha=1 fit/protocol and inference:
  `diagnostics/pnnn_loss_experiment/tp15ee449b_7a1a_4442_a6ae_cdefa2453e8a/`.
- Frozen three-model validation metrics:
  `diagnostics/pnnn_loss_validation/tpa1c233b4_dbd3_4fd6_b4ed_58dfa5b91317/`.

Raw x/y centered using the original DC-removal convention exactly reproduce
the stored sweep arrays. The mapping is x=u -> y=x_ILC, not PA-forward output.
All models are evaluated before CFR in the same centered target domain.
No delay, gain, phase or RMS correction was fitted for evaluation.

The architecture remains 84 features -> 12 sigmoid neurons -> 2 outputs.
There are 296 active weights (273 hidden, 23 output), 14 protected biases
and 736 fixed zeros. The new fit starts from the original pruned dense network,
not from either previously fine-tuned P310. A zero-update production call
reconstructs this initialization; its learnables exactly match the saved
alpha=1 initial network. Masks, statistics and partition indices also match.

Data: 491520 samples; identification 49151; disjoint development complement
442369. Historical internal selection used 41778/7373 rows within identification;
the final fine-tune uses all 49151 identification rows. Epoch count is fixed
at 164, not reselected. Dense statistics are reused; recomputed statistics
serve only as exact preflight checks.

Seed: 42 + offset 100000 = 100042, twister. All 164 randperm sequences were
replayed and exactly compared to the stored original permutations before
training. Batch size 1024, 48 batches/epoch (last batch 1023), 7872 updates.
Adam moments start empty. Learning rate remains
2e-4 * 0.95^floor((epoch-1)/41), with unchanged production Adam arguments,
gradient masking and weight remasking. Single-precision learnables and the
historical data/forward path are preserved. Acceleration stays disabled.

The previous diagnostic `lossPrunePNNN.m` and `weightedLoss.m` are called
directly, unchanged. No new training loop was copied or installed. The
options struct is exactly the previous one except LossWeights. The original
dense source is reused without training it. Reference models are not retrained.

## Loss formulation and preflight

Using the full-precision saved physical weights (rounded values in the user
request were not used to introduce a new numerical perturbation):

    w = [1.83551614008226, 0.164483859917741]
    wMixed = 0.5 + 0.5*w
           = [1.41775807004113, 0.582241929958871].

For 2-by-N normalized output tensors, dz=z_pred-z_target:

    Lmixed = mean(wMixed(:).*dz.^2, all)
           = 0.5*Lnorm + 0.5*Lfis
    Lnorm = mean(dz.^2, all)
    Lfis = mean(eI.^2+eQ.^2)/(sigmaI^2+sigmaQ^2)
    dLmixed/dz(c,n) = wMixed(c)*dz(c,n)/N.

Output standard deviations are the unchanged dense values
sigmaI=0.0125525119001017 and sigmaQ=0.00375762280052252. Physical coordinates
use the original input-phase rotation. Mean(wMixed)=1. The same positive
reference scaling as the previous experiment is used, not fitted from new
errors. Unit mean weights do not imply equal gradient norms or Adam paths.
Weights are cast to prediction precision by the unchanged helper.

Before reading the real training arrays, the actual scalar-loss helper passed
synthetic tests on 2-by-7 tensors. Absolute errors:

| Check | Observed maximum | Limit |
|---|---:|---:|
| Mixture identity for scalar loss | 8.8818e-16 | 1e-12 |
| Mixture identity for gradients | 1.1102e-16 | 1e-12 |
| Analytic gradient | 1.1102e-16 | 1e-12 |
| Central finite differences, step 1e-6 | 2.4568e-10 | 1e-8 |
| Single-precision gradient formula | 5.9605e-8 | 1e-6 |

No synthetic optimizer training was needed: the training loop is the identical
previously validated helper. The real fit ran once and took **69.1889825 s**,
excluding preflight and inference. It completed 164 epochs with exact final
RNG equality to the historical protocol. This is not a timing benchmark against
earlier runs; session/runtime variability precludes attributing timing changes
to alpha. The fit was saved before running analysis.

## Common evaluation definitions

For e=p-y and r=conj(x)/abs(x), with r=1 at x=0:

    NMSE = 10*log10(sum(abs(e).^2)/sum(abs(y).^2))
    MSEI = mean(real(r.*e).^2); MSEQ = mean(imag(r.*e).^2)
    MSE = mean(abs(e).^2) = MSEI+MSEQ; MAE = mean(abs(e))
    relativeL2 = norm(e)/norm(y)
    RMS = sqrt(mean(abs(p).^2))
    PAPR = 10*log10(max(abs(p).^2)/mean(abs(p).^2))
    angularRMSE = sqrt(sum(abs(y).^2.*angle(p.*conj(y)).^2)/sum(abs(y).^2)).

Angular RMSE is converted to degrees and weighted by target energy; zero
targets are excluded, and nonzero predicted magnitudes are verified there.
It is not RF EVM. Rotated Q is not identical to target-relative phase error.
Each metric is calculated with the same rows/targets for all four models.

## Results

| NMSE, dB | Historical alpha=0 | Mixed alpha=0.5 | Physical alpha=1 | PN-IQ-GMP |
|---|---:|---:|---:|---:|
| Identification | -35.111657 | -35.527836 | -35.738847 | -39.060027 |
| Development complement | -35.130808 | -35.564112 | -35.810940 | -38.855492 |
| Full development capture | -35.128892 | -35.560477 | -35.803688 | -38.875485 |

| Full-capture metric | Historical | Alpha=0.5 | Alpha=1 | PN-IQ-GMP |
|---|---:|---:|---:|---:|
| Physical I MSE | 1.398468e-7 | 1.205033e-7 | 1.050315e-7 | 5.412609e-8 |
| Physical Q MSE | 4.122536e-8 | 4.343986e-8 | 4.998288e-8 | 2.229134e-8 |
| Total physical MSE | 1.810722e-7 | 1.639431e-7 | 1.550144e-7 | 7.641742e-8 |
| Angular RMSE, degrees | 0.478547 | 0.485378 | 0.515253 | 0.327097 |
| Complex MAE | 2.979580e-4 | 2.833914e-4 | 2.760622e-4 | 1.811314e-4 |
| Relative L2 to ILC | 0.017520859 | 0.016671557 | 0.016211215 | 0.011382187 |
| RMS, native units | 0.024280766 | 0.024280683 | 0.024275603 | 0.024286927 |
| PAPR before CFR, dB | 13.879753 | 13.903841 | 13.956083 | 14.809420 |
| Historical normalized loss | 0.001903623 | 0.001920659 | 0.002103261 | 0.000961126 |
| Physical loss | 0.001054675 | 0.000954905 | 0.000902899 | 0.000445102 |
| Mixed loss | 0.001479149 | 0.001437782 | 0.001503080 | 0.000703114 |

For alpha=0.5 vs historical, full-capture changes are I MSE -13.83194%,
Q MSE +5.37169%, total MSE -9.45978%, MAE -4.88881%, angular RMSE +1.42749%.
Identification and development give consistent directions and similar sizes.
The mixed loss decreases 2.79667%, while the historical loss rises 0.89493%.
The new fit has the lowest mixed objective among the three neural endpoints;
this does not establish convergence or a global optimum. PN-IQ remains lower
under every listed loss, so its advantage is not just an evaluation-weighting
artifact on these frozen predictions.

The I improvement is 1.934353215e-8; the Q penalty is 2.214499506e-9,
cancelling 11.4483% of the I gain, versus 25.1542% for alpha=1. The net
physical-MSE reduction is 1.712903264e-8. Mixed NMSE is 0.243212 dB worse
than alpha=1, in exchange for much lower Q and angular penalties.
It retains 65.7349% of the alpha=1 improvement in physical MSE (63.9578%
when expressed as a fraction of the dB gain; these are different measures).

All neural variants retain 310 active real parameters and historical
780 FLOPs/sample. The mixed loss adds no inference operation. Predictions
are finite complex vectors of length 491520. Mixed RMS changes -0.0003413%
and PAPR increases 0.024088 dB from historical. These small offline changes
are not hardware transmission clearance; no safety limit was changed.

## Error by amplitude

All four models share exactly the same ten equal-count input-amplitude bins
(49152 samples each). Boundaries and all four models' absolute MSE, I/Q MSE,
MAE, NMSE, angular RMSE, error and reference-energy shares are in amplitude.csv.

| Decile | Mixed NMSE dB | Gain vs historical dB | Q MSE change | Angular RMSE change |
|---|---:|---:|---:|---:|
| 1 | -23.739546 | 0.783487 | +6.55% | -3.42% |
| 2 | -30.352058 | 0.654889 | +7.17% | +0.64% |
| 3 | -33.160392 | 0.637844 | +7.22% | +1.74% |
| 4 | -35.321500 | 0.622678 | +5.88% | +1.77% |
| 5 | -36.361863 | 0.606770 | +5.74% | +2.36% |
| 6 | -37.177083 | 0.609249 | +5.04% | +2.17% |
| 7 | -38.282285 | 0.591721 | +5.25% | +2.60% |
| 8 | -38.975960 | 0.485980 | +4.95% | +2.61% |
| 9 | -38.968266 | 0.420743 | +4.58% | +2.18% |
| 10 | -34.627765 | 0.274276 | +5.12% | +1.86% |

Mixed NMSE and MAE improve in all ten bins. Q worsens everywhere but much
less than with alpha=1. Angular error improves in the first bin and worsens
in the other nine, illustrating why rotated-Q error and target phase should
not be treated as interchangeable quantities.

The top decile still holds 52.6859% of mixed error versus 42.5034% of target
energy. This lies between historical 50.8117% and alpha=1 53.7890%; its NMSE
remains worse than deciles 8-9 even after energy normalization. Improvement
is smaller at the top than the bottom. A larger share does not imply larger
absolute error across models: PN-IQ concentrates 64.8055% of its smaller error
in the top decile. The first decile has only 0.4913% of target energy; its
poor relative NMSE does not imply dominance of total physical error.

The figure comparison.png is in the analysis directory. The 10% line in its
Q panel is a visual reference only; the locked acceptance criterion applies
to the aggregate development complement, not separately to each decile.

## Limits and next research priority

Only one new alpha=0.5 trajectory was run, using the original historical-loss
dense initialization. This does not test mixed loss during dense learning,
seed robustness, convergence, or optimal alpha. The mean-one scaling does
not neutralize changes in gradient allocation and Adam dynamics.

All reported numbers use already-examined development data. The preceding
inventory found no valid untouched compatible capture. No claim of independent
generalization or improved PA RF linearization follows from this result.
No extra runs were added to improve the conclusion.

The useful mixed-loss compromise justifies preserving and eventually validating
this model independently. It does not justify an open-ended alpha search.
Next prioritize a controlled comparison of what the frozen PN-IQ regressors
represent versus the PNNN features/shared hidden mapping, and how fitting and
conditioning differ, with identical physical conventions. The question is
whether the remaining error is predominantly representation, optimization,
or their interaction; this experiment cannot decide that. Study these
differences before prescribing a new neural architecture. Keep alpha=0.5
fixed as a reference so another moving loss choice does not confound that study.
Any new training or architecture intervention requires separate authorization.

## Artifacts and repository integrity

Fit directory: `tp390d053f_18ea_464b_8c05_db89f2b156eb/`.

- `experimental.mat`: new fit, elapsed time, final RNG and provenance.
- `protocol.mat`: alpha/weights, exact options, original-source references,
  masked initialization, expected RNG, numeric preflight test errors.
- `training_started.mat`, `execution.log`: one-fit guard and execution evidence.
- Analysis subfolder `tpc6c585a5_81aa_4b4a_8ac0_0ca4c0fbcf81/`:
  `metrics.csv`, `deltas_vs_historical.csv`, `amplitude.csv`, `analysis.mat`,
  `inference.mat`, `comparison.png`, `analysis.log`.
- Diagnostic code: `runMixedLoss.m`, `analyzeMixedLoss.m`; original training
  and metric helpers are reused read-only from the prior diagnostics.

Root Git started on main at 1600d268 with three pre-existing untracked
diagnostic directories and no tracked changes. SHA-256 remains identical
for all 563 source-manifest files, including the previous experiments and
validation. The only addition is this new diagnostic directory. No commits,
pushes or production edits were made.
