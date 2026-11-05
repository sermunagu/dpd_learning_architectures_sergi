# Validation record

MATLAB R2026a on Windows. No optimizer or hardware function was called.

## Scope and preserved artifacts

All previous loss-experiment files were read only. `integrity_before.csv`
and `integrity_after.csv` compare SHA-256 for 539 existing files, including
326 root-tracked files, the prior scientific data/diagnostics and all files
inside `pnnn_loss_experiment/`. The manifest is not a claim that every file
on the host was hashed. All 458 MAT files in the repository inventory were
inspected with whos; source arrays were loaded only where needed.

## Executed checks

- Inspected previous REPORT/VALIDATION, comparison CSV, saved experimental
  network, training/analysis/verification code and exact loss diff.
- Enumerated candidate files and inspected raw-capture metadata and derivative
  source provenance; no eligible untouched capture was identified.
- April/October input arrays equal exactly; target relative L2=0.1673100595.
  October raw copies agree exactly. April lacks exp_config. No fitted
  correction or independent comparison was applied to these targets.
- Before experimental inference, synthetic tests used five complex samples
  including a zero input. Feature/target shapes were 84-by-5 and 2-by-5.
  Phase restoration error norm <1e-12; NMSE vs 20*log10(relativeL2) <1e-12;
  MSE and relative L2 formula errors <1e-15. Incorrect row shape was rejected.
- Metric routine verifies MSEI+MSEQ=MSE with a relative budget of 1e-12
  (floor at eps) and finite, equal-size column vectors for every call.
- Identification/development indices are disjoint and their union covers
  every sample exactly. Weighted training rows equal original identification.
- Saved dense/baseline/weighted normalization equal exactly. Neural masks,
  learnable shapes and all pruned zeros were checked; bundle baseline
  learnables equal the point checkpoint.
- Frozen historical and weighted inference equals saved predictions exactly.
  PN-IQ uses the same block operations as applyDPDModels and exactly equals
  the saved linear sweep prediction. No training peak or z-score was refitted.
- All models use the same targets, rows, decile boundaries and phase bins.
- 10 deciles, 12 phase sectors and 120 crossed cells per model are descriptive
  summaries of this capture, not independent replication units.
- Figure inspected visually after MATLAB export; all panels are readable.

## Execution history

The first metadata inventory stopped because a historical cfg struct lacked
the assumed data field. The diagnostic was changed to display its actual
schema. The original partial log is retained as `inventory.log`; the completed
inventory has its own fresh folder. This was a metadata-only failure and no
model computation or source write occurred.

`analyzeFrozen` completed once in
`tpa1c233b4_dbd3_4fd6_b4ed_58dfa5b91317`. No real or synthetic training took
place. The first static check found one unnecessary comma in synthetic
try/catch syntax; it was expanded without changing computation. A final
static check is recorded separately, with no need to repeat inference.

## Reproduction

Read the saved CSV files for the completed result. If a fresh reproduction is
needed, from the repository root in MATLAB:

```matlab
addpath('sergi_pniq_dpd/diagnostics/pnnn_loss_validation');
analyzeFrozen;
```

It performs synthetic checks and frozen inference, creates a unique output
folder, and does not modify previous artifacts. `auditInventory` and
`completeAudit` guard completed CSVs against accidental overwrite.
The inventory uses the preserved `mat_files.txt` as its original search scope.

For any metric M in metrics.csv, percent change is
100*(M_variant/M_historical-1); NMSE delta is simple dB subtraction.
This also specifies `deltas_vs_historical.csv` generated from the saved table.
PAPR/RMS on indexed identification/development subsets are sample-subset
descriptors, not PAPR of a separately transmitted waveform; use the full
capture row when discussing signal transmission characteristics.

All code/docs use ASCII and CRLF. Results stay in this diagnostic directory.
No source preprocessing, scientific configuration, safety checks or models
were edited. There is no independent-capture evaluation to reproduce until
the missing compatible untouched data are provided.
