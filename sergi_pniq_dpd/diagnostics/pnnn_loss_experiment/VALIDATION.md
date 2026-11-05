# Validation and reproducibility

Run: `tp15ee449b_7a1a_4442_a6ae_cdefa2453e8a`.
See REPORT.md for interpretation, all sources and the scientific limitations.

## Executed before the single real fit

All assertions passed before `training_started.mat` was written.

| Check | Criterion and result |
|---|---|
| October capture | Provenance filename plus exact equality of centered raw x/y and experiment x/y; pass |
| Feature width and duration | 84 features, saved 164 epochs; pass |
| Normalization | Saved baseline and dense stats identical; recomputed identification means/stds identical; pass |
| Baseline recovery | Reconstructed prediction `isequal` saved prediction; pass |
| Baseline NMSE | Absolute difference from -35.1288921476265 <1e-10 dB; pass |
| Dense-derived pruning | Production call with zero epochs; masks exactly equal saved P310; pass |
| Counts | 296 active weights and 14 protected biases; pass |
| Weights | Dense statistics only, abs(mean(w)-1)<1e-14; pass |
| Synthetic loss | Double 2-by-7 CB tensors; physical identity absolute error <1e-12; pass |
| Synthetic gradient | Every component agrees with w.*(pred-target)/7 within 1e-12 absolute; pass |
| Historical loss recovery | Weights [1,1] reproduce scalar historical loss and analytic gradient within 1e-12; pass |
| Phase restoration | Round-trip complex phase error norm <1e-12; pass |
| Copied loop integration | One synthetic 32-row epoch, weights [1,1]: exact production learnables, masks and final RNG; pass |
| Weighted masking | One synthetic 32-row epoch with physical weights, all pruned values exactly zero; pass |
| RNG protocol | Replay 164 randperm calls at seed 100042; final state exactly equals saved historical original P310 control; pass |

The scalar tests validate both the factor of two in a mean over 2*N entries
and the channel/batch orientation. The synthetic integration tests use
synthetic features and targets with the dense statistics. They are not extra
real-data training runs and do not provide the reported scientific NMSE.

The real fine-tune uses the same copied randperm loop and seed. It does not
feed the saved permutations back into a different training implementation.
`protocol.mat` stores those permutations as a reproducibility witness; code
identity, unchanged RNG calls and exact final RNG jointly support the sequence
claim. Final RNG equality alone would not prove identical scientific results.

## Single real fit and saved-result checks

The real fit ran once: 164 epochs, 7872 Adam updates, 111.5319697 seconds.
No real historical-control fit was rerun. Dense training was never invoked.
The diagnostic driver refuses to start another real fit if either an existing
`experimental.mat` or `training_started.mat` is found below this directory.
Do not remove these guards merely to rerun completed work.

The resulting model was saved before running analysis. The analysis reloads
that saved model; thus reported inference uses the persisted artifact.
`verifySavedExperiment` subsequently loads the artifacts without training.

| Saved-result check | Result |
|---|---|
| Masks vs dense initialization and historical P310 | Exact equality |
| Final RNG vs expected historical control | Exact equality |
| Final epoch | 164 |
| Graph connections, layer classes, learnable names and dimensions | Same as historical |
| Learnable precision | Single for all four tensors |
| Layer active entries | 273, 12, 23, 2; all active entries nonzero |
| Pruned entries | All 736 exactly zero in both models |
| Parameters | 296 weights + 14 biases = 310 |
| Inference model saved learnables | Exactly equal to saved fitted network |
| Normalization and network state | Unchanged |
| Prediction shape and finiteness | 491520 complex samples; no NaN/Inf |
| Historical FLOP convention | 780 for each model |
| Static analysis | checkcode on all five new MATLAB files returned no messages |

Weights are deliberately different under the loss intervention, not expected
to be bitwise equal. Maximum absolute changes per learnable tensor are
0.136499286 (hidden weights), 0.111482739 (hidden biases), 0.153598070
(output weights), and 0.0361761451 (output biases). These are scientific
training differences, not the tiny dlaccelerate numerical discrepancies
studied in earlier tasks. Inference itself is the unchanged production path.

No tolerance was used to conceal a Q regression: Q MSE rises in every domain.
All ten common amplitude deciles improve complex MSE and MAE; their exact
boundaries and both sets of energy shares are preserved in amplitude.csv.

## Independent integrity evidence

`integrity_before.csv` and `integrity_after.csv` contain absolute paths and
SHA-256 values for 505 existing files. Every pair matches, including all 326
tracked root files, 151 historical data files and all 28 pre-existing
TAREA 01 artifacts. The source checkpoint, prediction and documentation
files were only read. The source tree had no tracked changes before or after.
Root HEAD and branch remain unchanged; no Git mutation was made.

New code and documentation use ASCII and CRLF; original bytes were not
normalized. The human-readable diff ignores end-of-line whitespace so that
the small scientific change is reviewable against the mixed-ending original.

## Reproduce analysis without training or hardware

From the repository root in MATLAB R2026a:

```matlab
addpath('sergi_pniq_dpd/diagnostics/pnnn_loss_experiment');
out = fullfile('sergi_pniq_dpd','diagnostics','pnnn_loss_experiment', ...
    'tp15ee449b_7a1a_4442_a6ae_cdefa2453e8a');
analyzeLossExperiment(out);
verifySavedExperiment(out);
```

These calls regenerate only the derived CSV/inference artifact and verification
log in this diagnostic run folder. They do not overwrite the experimental fit,
protocol, checkpoints or historical results. The already-produced artifacts
are sufficient for review, so executing these commands is optional.

`runLossExperiment` documents the complete protocol but intentionally rejects
another real fit now. No main hardware script or instrument function is called
by any of these diagnostic scripts.

Reproduction in another MATLAB release, device or numerical environment may
not be bitwise identical. Absolute signal power is reported in native numerical
units, not calibrated dBm. Finite outputs and modest RMS/PAPR changes do not
replace the repository's RF safety checks or authorize transmission.
