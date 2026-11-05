# Validation of the one P310 readout LS experiment

MATLAB 26.1.0.3203278 (R2026a), PCWIN64, 20 reported threads. Date 2026-11-04.
The only real-data optimization consisted of two independent SVD coefficient
solves, one for I and one for Q. The helper is shared with the synthetic test.
No model training, dense fit, Adam, pruning, CFR or hardware was executed.

## Preconditions and synthetic test

PROTOCOL.md fixed the numerical method, tolerances and practical criterion
before the real fit. A separate preflight invocation finished successfully
before the real-fit invocation. The synthetic four-hidden-unit network uses
deterministic coefficients, different I/Q masks, a final bias column, known
readout coefficients and nontrivial complex phases. Its original and refitted
outputs are checked with the same readout helper as the real experiment.

| Check | Observed | Gate |
|---|---:|---:|
| Synthetic sigmoid versus explicit calculation, max abs | 5.53214e-8 | <1e-6 |
| Original synthetic output reconstruction, relative L2 | 4.18729e-8 | <1e-6 |
| Known double LS coefficient solution, max abs | 3.33067e-16 | <1e-10 |
| Updated synthetic output reconstruction, relative L2 | 6.39297e-8 | <1e-6 |
| Synthetic phase restoration, max abs | 7.31505e-9 | <1e-6 |
| Known complex synthetic prediction, relative L2 | 5.67675e-8 | <1e-6 |

Both synthetic designs have rank 4. Hidden coefficients and activations remain
exactly unchanged, masks with different missing output connections are obeyed,
bias mapping is correct and output precision remains single. Synthetic setup
restores its entry RNG state; it does not alter the real experiment's RNG.
The positive-loss-weight invariance follows algebraically by cancelling w_c
from the independent stationarity equations; no extra weighted fit was run.

## Real preflight

- Mixed experimental.mat/protocol.mat agree in provenance and historical RNG.
  The located inference model's learnables equal the experimental network.
- Centering the actual October raw arrays reproduces saved x/y exactly.
  The source capture identity is October 23. No April target is read.
- Masks equal historical P310 masks without re-pruning; their active counts
  are [273,12,23,2], with 736 absent weights and 12/13 permitted readout
  coefficients including bias. All allowed entries are nonzero single values.
- Saved normalization matches the mixed provenance, dense source and original
  P310 model. The same saved feature configuration is used, without replacing
  any normalization statistic. Identification rows equal the original training
  rows; id and complement are disjoint and exhaust the complete record.
- The original predictPNNN output equals the saved mixed prediction exactly.
- Hidden activations are extracted by predict(...,Outputs="sigmoid1") from
  the original network, with the original input and default settings. They
  are single, while normalized inputs/targets are double. The LS designs use
  double copies of these native activations, not manually recomputed sigmoids.
- Before changing coefficients, double readout reconstruction differs from
  normalized network inference by 1.25868e-7 relative L2; after original output
  scaling/phase it differs by 6.50498e-8. Both pass the predeclared 1e-6 gate.
- Real preflight leaves RNG exactly unchanged.

## Real solve and rounding controls

Both designs have full column rank (12 and 13), with minimum singular values
3.35446 and 3.31221, far above tau=2.79391e-9. There is no rank truncation,
Ridge or development-selected numerical setting. Raw conditions are 126.5783
and 137.6165; column-L2-scaled conditions are reported separately.

The helper uses the economy SVD formula directly. A'*e is evaluated only
after solving to diagnose stationarity. Relative normal-equation residual is

    ||A'*e|| / (||A||_F * max(||target||,||e||)).

The target-based denominator remains meaningful for the near-exact synthetic
fit. Real double residuals are 1.52804e-15 and 2.17020e-14, below 1e-10.
Maximum absolute uncentered normal-equation cosines are 6.70583e-14 and
4.00980e-13. These establish conditional numerical optimality, not a global
neural optimum. The gradients differ slightly from the earlier audit because
that audit evaluated hidden sigmoids in double; this fit uses native activations.

Each beta is cast to its original learnable precision. Rounding satisfies
abs(beta_single-beta_double)<=eps(single)*abs(beta_double)+realmin.
Maximum coefficient differences are 5.81882e-8 / 5.52249e-8, relative L2
2.22194e-8 / 1.85478e-8. All 25 permitted coefficients remain nonzero.

On identification, the actual normalized-inference loss decreases from
0.00144614138301684 to 0.00143661111575075. For a double residual e and a
forward perturbation delta, the component MSE discrepancy is bounded by

    (2*norm(e)*norm(delta) + norm(delta)^2)/N.

The check includes both original and refitted forward discrepancies, applies
the fixed w_c/2 factors and adds 100*eps for double reductions. The resulting
allowed loss budget is 1.74129e-8; the observed decrease is about 9.53027e-6.
Both normalized component MSEs decrease within the corresponding bounds.
This budget was calculated on identification, not tuned from development.

Actual network output versus rounded-coefficient double accumulation differs
by 1.26869e-7 normalized relative L2, within the 1e-6 gate. Restored complex
inference versus ideal double LS differs by 6.62560e-8 relative L2 and
1.43420e-8 maximum absolute error. The corresponding full NMSE difference is
1.03016e-7 dB. Coefficient casting alone contributes 1.49527e-8 relative L2.
There is no requirement or claim of bitwise identity between different
precision arithmetic paths.

The actual network normal-equation cosines are 8.22347e-7 / 6.41501e-7,
and target-scaled residuals 1.93292e-8 / 3.44732e-8. These are consistent with
single arithmetic, rather than evidence of a failed LS solve.

## Invariance, serialization and comparisons

Exact comparisons verify hidden weights/biases, hidden activations, network
connections/state, layer objects through sigmoid1, feature configuration,
normalization, masks, learnable shapes and precision. Every masked entry is
zero and every permitted entry remains nonzero: 296 weights + 14 biases =310.
Historical neural FLOPs remain 780 and the PN-IQ comparator remains 1013.
These are analytic conventions; no runtime/latency claim follows.

The real fit leaves RNG unchanged. The new model was saved before subsequent
evaluation. Reloading readout_model.mat and running original predictPNNN
reproduces inference.mat exactly. The reload check also verifies hidden
parameters, masks, normalization and RNG.

Reference NMSE and MSE reproduce the prior comparison within 1e-10 dB and
1e-18 respectively; mixed loss agrees within 1e-15. Common physical metrics
reuse the prior errorMetrics helper without edits. Magnitude and angular
definitions match the gap audit. Complete-record RMS/PAPR describe the
actual candidate waveform; subset values are not separate transmit waveforms.

The original sorted input-amplitude bins have identical counts and exact
min/max boundaries against the prior binary analysis.mat table. Baseline-bin
MSE agrees within 1e-18. An initial comparison against decimal amplitude.csv
failed bitwise equality because its serialization changes boundaries by at
most 4.85723e-17. This was an analysis-validation issue, not a model or bin
change. The exact MAT comparison replaced that check; the saved LS fit was
never rerun. The corrected analysis succeeded and saved all tables once.

The development criterion was evaluated after fitting: gain 0.0160116083 dB
<0.10, Q change -0.5343024% <=+10%. Overall criterion false. No hyperparameter,
rank threshold, alpha, readout variant or later fit was chosen to improve it.

## Guards, static analysis and integrity

fit_started.mat is written before either real coefficient solve. The fit entry
point refuses when any started/completed fit already exists; preflight also
refuses. Analysis refuses when final tables already exist. All three guards
were exercised after completion and rejected repetition before any operation
that could overwrite results. This did not repeat fitting or analysis.

Final static analysis is recorded in saved_verification.log. It reports no
messages for analysis, synthetic test, static-check wrapper or saved-model
verification. Remaining advisory messages are one numel-versus-isscalar style
suggestion in the runner and two redundant AGROW suppression comments in the
solver. They do not affect calculations and were not used to justify reruns.

The original 583-file audit manifest was verified before starting; its 29
additional gap-audit artifacts were also protected here, totaling 612 files.
All 612 after hashes match. The before/after CSV manifests themselves have
SHA-256 800FB251B6F9E7E0AC4C2C997FACA88FCE454F5AA04375CD2B15568BADAC7CD1.
No original diagnostics, production code, tutor files, checkpoint or historical
result changed. Own code/protocol hashes are recorded separately for provenance.

Root branch main and HEAD 1600d268c38378ad0d4fb689e7ca64dcb438f418 are unchanged,
without tracked/staged edits. Only the new pnnn_readout_ls directory was added
to the prior untracked diagnostics. No commit/push or destructive Git command.

## Reproducibility and artifact use

The completed run is tp927d59fa_d1a5_4040_a786_7820557ca62f. Read its CSV/JSON
or load readout_model.mat (model, fit, provenance) and inference.mat (prediction,
verification) to inspect the result without rerunning anything.

The recorded sequence was runReadoutLS('preflight'), then
runReadoutLS('fit',runFolder), then analyzeReadoutLS(runFolder), then
verifySavedReadoutLS(runFolder). Each stage uses only files in this diagnostic
directory for outputs. Do not remove guards to repeat this authorized fit.
prepared.mat intentionally retains the original feature cache for transparent
reproduction without another feature-building pass. All new code/docs are
ASCII/CRLF; CSV and MATLAB log conventions are retained as generated.

This remains a development-data intervention with no independent validation,
RF measurement, confidence interval or claim of universal architecture ranking.
The single next experiment recommended in REPORT.md remains unexecuted.
