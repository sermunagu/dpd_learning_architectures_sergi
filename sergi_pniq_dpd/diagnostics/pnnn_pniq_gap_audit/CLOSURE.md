# Audit closure

Closed on 2026-11-04. This continuation reviewed existing evidence and completed
file integrity verification. No MATLAB process, model inference, training,
LS refit, sweep, CFR, hardware operation, commit or push was executed.

## Initial state and recovered artifacts

Root branch: main. HEAD: 1600d268c38378ad0d4fb689e7ca64dcb438f418.
There were no tracked modifications. Git reported five pre-existing untracked
diagnostic directories: pnnn_root_cause, pnnn_loss_experiment,
pnnn_loss_validation, pnnn_mixed_loss and pnnn_pniq_gap_audit.

The current audit directory contained 26 files: the three MATLAB helpers,
REPORT.md, VALIDATION.md, integrity_before.csv, summary.log, two metadata
inspection directories and the main analysis directory. All were retained.

- `tp06afc936_f56e_43aa_b4ed_2065a0269374/`: first inspection log and basis CSV.
- `tp22743bea_bfe0_448b_bf54_ec7980ccb1c6/`: corrected inspection log and CSV.
- `tp7d131b74_614e_4611_8771_7807054f30c4/`: completed audit log, audit.mat,
  12 CSV tables and residuals.png.

Frozen inference equality, metrics, residual/spectral analysis, synthetic
derivative checks and static analysis were already complete. summary.log was
valid and was not regenerated. The original final integrity manifest was
missing; no model computation was necessary to complete it.

## Additional verification and corrections

1. Read all three audit helpers and both reports; reviewed completed logs and
   saved tables against relevant original source code without executing it.
2. Verified current/past/future indexing from periodic row construction and
   actual P310 selected columns. Future-feature indices in the selected-column
   table are 7,24,36,46,78,81,96,115,143,144,145. They refer to envelope lags
   -1/-2, not extra past taps or the entire candidate dictionary.
3. Verified the only difference between the two metadata CSVs is the already
   corrected degree of envelope-only feature 109 (2 -> 1). All numerical
   model predictions remain unaffected; neither CSV was overwritten.
4. Checked parameter allocation: PN-IQ has 155 nonzero coefficients per output;
   the saved neural connection tables and prior mixed-loss validation give
   273 hidden weights, 12 hidden biases, 23 output weights and 2 output biases.
   Both models have 310 active real parameters. Features, function classes,
   special operations, storage and latency are distinct quantities.
5. Checked that readout gradients use identification rows and the mixed
   objective, including its factor 1/(2*N). Conditions concern the smooth
   double surrogate, whose prediction difference was previously measured.
   They establish conditional nonstationarity, not Adam failure or a known
   recoverable NMSE gain. Existing finite-difference evidence was reused.
6. Checked the masked LS proposal mathematically. It fits 12 I and 13 Q
   coefficients including biases; it freezes the hidden path, normalization
   and mask. Positive per-output weights do not change the conditional LS
   minimizers. The target, precision and identification-only rank rule are
   now explicit. This remains documentation, not implementation.
7. Rehashed all original manifest paths. Both CSV manifests have schema
   Path,Hash, 583 unique rows in the same order, and identical file hashes:
   AB6F2F3EB2E478F8D015478355CF4BB54F38496FDD078BD3D1E93D12B5BCE69D.
   Result: 583 matches; zero missing, unreadable or changed files.

Two documentation issues were corrected: the premature claim that final
integrity verification was complete, and the claim that all Markdown used
CRLF. Existing scripts are ASCII/CRLF; the two existing reports are ASCII/LF
and retain those endings. This new closure document is ASCII/CRLF.

The conclusion was made explicitly noncausal, and the pruning assessment was
narrowed: pruning cannot explain the pre-existing dense gap, but its causal
contribution to sparse performance is not measured. No numerical result or
previously tested scientific outcome changed.

## Final scientific position

Full development-capture NMSE remains -35.128892 dB (historical PNNN),
-35.560477 dB (mixed), -35.803688 dB (physical loss), and -38.875485 dB
(PN-IQ-GMP). Historical/physical-loss values are reused from the prior
mixed-loss comparison; this audit's principal frozen comparison is mixed
versus PN-IQ. The latter's 3.315009 dB advantage appears across all audited
amplitude deciles and temporal blocks.

The models differ in explicit nonlinear memory products, selected look-ahead,
absolute-phase auxiliaries and 155 explicit features versus 12 learned hidden
activations. Conditional output optimization is incomplete in the frozen
neural endpoint. These are verified structural/numerical facts; their separate
contributions to the NMSE gap remain unmeasured. Neither hidden capacity,
pruning, missing future samples nor a particular optimizer is proven to be
the cause. No historical loss curves support a convergence or plateau claim.

All observations concern previously used development data and ILC imitation.
They establish neither independent generalization, improved RF linearization,
nor a universal architecture ranking. No inference memory/latency benchmark
was performed. Correlated residual features are descriptive, not causal.

The recommended next experiment is one masked output-only LS refit on the
original identification rows. It isolates recoverable final-readout error
without changing hidden features or increasing the parameter budget. Small
improvement would narrow the diagnosis but would not distinguish hidden
optimization from representation/input limitations. Development metrics are
evaluation descriptors, not a source for solver or hyperparameter selection.
The experiment has not been implemented or executed.

## Files and final Git state

Edited only REPORT.md and VALIDATION.md, with targeted clarifications.
Added integrity_after.csv, integrity_summary.json and this CLOSURE.md.
All other 24 recovered files, including scripts, logs, CSV/MAT data, image and
the original manifest, retain their initial hashes. The 583 protected original
files also remain identical. No prior experiment directory was modified.

Root HEAD and branch are unchanged, with no tracked or staged modifications.
git status --short still reports the same five untracked diagnostic directories.
The audit is closed; the proposed LS experiment requires a separate task.
