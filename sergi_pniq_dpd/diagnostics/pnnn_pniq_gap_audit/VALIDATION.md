# Validation and limitations

MATLAB R2026a. This audit never calls trainnet, adamupdate, a model-fitting
helper, a hardware script or an instrument function. Reading their source
does not execute them. No gradient step, least-squares coefficient solve,
ablation, altered prediction model or hyperparameter experiment was performed.

Executed:

- Synthetic complex metrics, Parseval equality and positive/negative periodic
  lag checks before real signal processing; absolute energy error <1e-15.
- Exact equality of reconstructed mixed inference and saved mixed prediction.
- Exact equality of reconstructed PN-IQ inference and saved linear sweep P310
  prediction; no new peak/z-score normalization was estimated for inference.
- Dense inference recomputed from its saved network, confirming the earlier
  -35.572399266724 dB endpoint. No dense optimization was repeated.
- Mixed masks checked against historical P310; parameter connections and
  nonlinear activation statistics computed directly from stored learnables.
- Double manual forward calculation versus original inference: relative
  prediction L2 8.34320580495e-8, below the explicit 1e-5 diagnostic budget.
  This double representation is used only for readout derivative diagnostics;
  all reported performance metrics use original frozen predictions.
- Fixed-readout analytic derivative checked against central differences on a
  small synthetic matrix: max absolute discrepancy 4.7837e-12, limit 1e-9.
- No stationarity-based improvement was estimated through an unreported fit.
  Normal-equation cosines are derivative descriptors, not attainable-NMSE bounds.
- Common metrics assert equal finite column vectors and consistency of
  physical I/Q energy with complex MSE. Ten input and correction bins share
  sample indices across the models. Pearson correlations use development rows.
- Full residual spectral energy matches time-domain MSE within 1e-12 relative.
  FFT bin powers, PSD conversion and 60-bin visual averaging are explicit.
- Visual inspection of residuals.png confirmed readable panels/labels.
- Static analysis of all three scripts returned no messages.

The main analysis ran once. Model metadata was inspected a second time only
to correct the envelope-only auxiliary's degree label; canonical degree and
lag counts were also independently summarized from saved descriptors. The
corrected CSV directory is identified in REPORT.md; the earlier inspection
log remains for traceability. No original artifacts were overwritten.

Metadata degree for canonical features is 1+sum(envelope powers); a pure
envelope auxiliary lacks that carrier and has degree sum(envelope powers).
Phase-normalization introduces divisions and symmetry conventions, so these
degrees describe the underlying homogeneous carrier/envelope term, not a
claim that the entire normalized predictor is a polynomial in raw I/Q.

PN-IQ basis condition uses peak-scaled columns; neural readout condition
uses column L2 normalization. They describe their respective problems and
must not be read as a controlled common-scaling optimizer experiment.
Individual highly correlated polynomial coefficients are not importance scores.
Pearson correlations of near-zero structural features can be undefined or
dominated by floating-point residue. No causal claim is based on those rows.

No historical train/validation curves or Adam moments were recovered because
the relevant source/model schemas do not save them. Profiling epoch timings
are not loss traces. Budget-cap and endpoint observations cannot demonstrate
a plateau, learning-curve trend, seed sensitivity or global neural capacity.

All data are development data. Future-envelope selection, auxiliary columns,
correlated residuals, spectral differences and readout nonstationarity are
audited facts/descriptors; their causal shares require controlled intervention.
No independent generalization, PA compression regime, RF EVM or ACPR result
is inferred. The proposed single readout experiment remains unexecuted.

Reproduction from repository root, if desired:

```matlab
addpath('sergi_pniq_dpd/diagnostics/pnnn_pniq_gap_audit');
auditGap; % New unique output directory; frozen inference/analysis only.
inspectModels; % New unique metadata directory; read-only source models.
```

finishAudit is guarded against overwriting its completed summary log. Existing
CSV/MAT artifacts suffice for review; no rerun is necessary. Scripts are
ASCII/CRLF; the existing ASCII Markdown reports retain their LF line endings.
All 583 original-file SHA-256 pairs in the manifests agree. No tracked
modifications, commits or pushes occurred.

## Continuation closure, 2026-11-04

No MATLAB function was invoked again. The completed logs and tables were
reviewed against the three audit scripts, the original feature builders,
weighted loss, prediction path, least-squares fit and operation-count source.
Both original and corrected metadata tables were preserved: their only
changed cell is feature 109, Degree 2 -> 1, for the envelope-only auxiliary.
The corrected selected support has 155 nonzero coefficients per output,
152 canonical columns, 11 future-envelope columns and three auxiliaries.

The 25 saved readout derivatives use identification rows, mask-permitted
activations plus bias, and the alpha=0.5 loss. The mean over two output
channels supplies the factor 1/(2*N), so its derivative is w_c*A_c'*e_c/N.
This is a double-surrogate conditional-stationarity diagnostic; no inference
is made about Adam failure or attainable development NMSE from its magnitude.

The proposed LS formulation now states the normalized targets and mask
mapping explicitly, requires the unchanged hidden inference path, and fixes
the numerical rank rule from identification alone. It adds no parameter or
development-selected hyperparameter. All such operations remain proposed;
no solver, refit, new prediction or training was run during closure.

The previously absent `integrity_after.csv` was created by rehashing all 583
original paths, preserving schema and row order. All 583 exist and match;
there are zero missing, unreadable or changed files. The before/after CSV
files themselves have the same SHA-256. `integrity_summary.json` records the
counts and manifest hashes. This closes the earlier unsupported assertion
that the final manifest check had already completed. `CLOSURE.md` records
the final scope, remaining scientific limitations and Git state.
