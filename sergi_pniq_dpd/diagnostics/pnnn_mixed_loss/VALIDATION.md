# Validation and reproducibility

This task executed one and only one real P310 fine-tune, alpha=0.5, 164 epochs,
7872 updates. No dense/reference/synthetic optimizer training was performed.
The zero-epoch production call only reconstructed the original masked network.

## Before training

PROTOCOL.md locked the development interpretation thresholds before the run.
`runMixedLoss` calls the unchanged prior weighted-loss helper in the synthetic
loss/gradient tests. The scalar mixture, gradient mixture, closed-form gradient,
central finite difference and single-precision checks all passed. Numerical
errors and tolerance values are listed in REPORT.md and stored in protocol.mat.

Full-precision saved weights reproduce the user-provided rounded values within
5e-11; their mean is one within 1e-14. Dense-derived physical weights exactly
equal the saved weights. The mixed values are exactly 0.5+0.5*w.

The raw centered capture equals stored x/y. Normalization equals dense and
baseline normalization; recomputed identification means/stds agree exactly.
84 features and 164 saved epochs were asserted. The options struct equals the
alpha=1 options except LossWeights; useAcceleration=false and fixed epochs
were explicitly asserted. All 164 row permutations equal the saved uint32
orders, and their final RNG equals the saved expected state.

The initial pruned network learnables exactly equal the previous initial
network; masks exactly equal historical P310 and previous alpha=1 masks.
No preprocessing statistics or initialization values were replaced.

## After training

The fit was saved to experimental.mat before post-fit assertions or analysis.
Its bestEpoch is 164; active counts are 296 weights and 14 biases. Final RNG
exactly equals the historical expected RNG, and masks remain exactly equal.
Saved-result analysis checks graph connections, layer classes, network state,
learnable names/shapes/precision and all pruned zeros. Active entries remain
nonzero and every parameter is finite. Historical FLOP accounting remains 780.

Analysis reloads the saved fit before inference. The prediction is a finite
complex column vector of length 491520. Existing reference predictions are
reused from their frozen checkpoints: all three were independently reproduced
bit for bit by the previous validation. Their newly computed NMSE values
match the previous CSV within 1e-10 dB, and MSE within 1e-18 absolute.

`errorMetrics` from the previous validation is reused without edits. It checks
dimensions, finiteness and MSEI+MSEQ consistency at every evaluation. The same
samples and amplitude boundaries are used for all four models. Angular
metrics use the exact same energy-weighted wrapped-phase formula as before;
predicted phase is verified defined on all nonzero reference samples.

The figure was visually inspected. Initial static analysis found one unused
rotation reshape after inference; it was removed from analysis code only.
Final static analysis is recorded separately. No training or analysis results
were recomputed because of this computationally inert cleanup.

All 563 pre-existing files in integrity_before.csv retain their SHA-256 in
integrity_after.csv. This includes previous diagnostics and scientific sources,
not every file on the computer. Root tracked files and HEAD are unchanged.
New code/docs use ASCII and CRLF. MATLAB/environment details are in provenance.

## Reproducibility without another fit

From repository root in MATLAB R2026a:

```matlab
addpath('sergi_pniq_dpd/diagnostics/pnnn_mixed_loss');
analyzeMixedLoss(fullfile('sergi_pniq_dpd','diagnostics','pnnn_mixed_loss', ...
    'tp390d053f_18ea_464b_8c05_db89f2b156eb'));
```

This creates a new unique analysis subfolder and never trains or overwrites
previous results. It requires the preserved preceding diagnostic helpers
and original source files, whose paths and hashes are recorded.
The saved CSVs already provide the complete result; reproduction is optional.

Do not rerun training: runMixedLoss refuses if training_started.mat or
experimental.mat already exists in a run directory. Do not remove those
guards to bypass the user's one-fit limit. There is no automatically scheduled
follow-up, alpha sweep or hardware operation.

RMS/PAPR on identification/complement subsets describe those selected samples,
not separate transmit waveforms; use full-capture rows for waveform comparisons.
Native numerical units are not calibrated dBm. Development acceptance is not
independent generalization, statistical significance or RF safety certification.
