# PNNN research data availability and publication audit

The seven pnnn_* diagnostic studies are published through hidden-only continuation.
No TAREA 05 is included. Existing scientific files are preserved byte for byte.
PNNN_PUBLICATION_MANIFEST.csv classifies all 206 original files and records SHA-256.
A: source/documentation/aggregates; B: inspected model/state/metadata MAT;
C: restricted sample-level artifacts; D: conservatively excluded ambiguous MAT.

MAT inspection used h5py for v7.3 datasets and scipy metadata inspection for
legacy MAT files, plus the original saving code. No MATLAB or experiment ran.
Large arrays retained in protocols contain deterministic shuffle permutations
and identification indices, not signal values. Models contain normalization
statistics, masks and learned coefficients. Scientific logs contain settings,
object schemas, summary tables and epoch traces; no credential tokens or full
waveform dumps were identified. Local source paths are retained as provenance.
CSV files are metrics, coefficient/basis tables or integrity inventories, not
sample predictions. error_spectrum.csv is an averaged residual power spectrum,
not complex FFT coefficients. The three PNGs visualize aggregate diagnostics.

## Local-only artifacts

Specific root .gitignore rules protect the following files. They have not been
removed, moved, rewritten or put in LFS. Hashes are in the publication manifest.

- `sergi_pniq_dpd/diagnostics/pnnn_hidden_continuation/tp1442baa6_833f_4abe_a213_602d50180629/inference.mat`: Complete per-sample features, targets, rotations or complex predictions.
- `sergi_pniq_dpd/diagnostics/pnnn_loss_experiment/tp15ee449b_7a1a_4442_a6ae_cdefa2453e8a/inference.mat`: Complete per-sample features, targets, rotations or complex predictions.
- `sergi_pniq_dpd/diagnostics/pnnn_mixed_loss/tp390d053f_18ea_464b_8c05_db89f2b156eb/tpc6c585a5_81aa_4b4a_8ac0_0ca4c0fbcf81/inference.mat`: Complete per-sample features, targets, rotations or complex predictions.
- `sergi_pniq_dpd/diagnostics/pnnn_readout_ls/tp927d59fa_d1a5_4040_a786_7820557ca62f/analysis.mat`: Contains full capture amplitude rank ordering (491520 sample indices).
- `sergi_pniq_dpd/diagnostics/pnnn_readout_ls/tp927d59fa_d1a5_4040_a786_7820557ca62f/inference.mat`: Complete per-sample features, targets, rotations or complex predictions.
- `sergi_pniq_dpd/diagnostics/pnnn_readout_ls/tp927d59fa_d1a5_4040_a786_7820557ca62f/prepared.mat`: Complete per-sample features, targets, rotations or complex predictions.
- `sergi_pniq_dpd/diagnostics/pnnn_root_cause/tp0f242878_e7a5_4587_93ac_7eda9246e580/analysis.mat`: Legacy MAT serialized objects not fully inspectable without MATLAB; aggregate CSV alternatives retained.

## Reproduction with authorized private data

A public clone permits inspection of code, fitted checkpoints, metrics and
validation evidence. It cannot independently reproduce data-dependent metrics
without the private October capture and original sweep artifacts. Published
historical reports/manifests describe the complete local experiment and may
reference deliberately unpublished files; those references are not claims
that raw or sample-level data are downloadable.

Restore the authorized private capture experiment20261023T102742_xy.mat and
original October sweep tpf1484cb1_eb1d_4fe1_9d7e_13899ee8f7e5, including its
experiment, dense source, P310 bundle and linear predictions, at the documented
local paths. Prefer restoring the excluded caches from the private archive
and checking their manifest hashes. Do not launch a new training entry point
merely because a cache is absent; the published one-run guards are intentional.

If regeneration is necessary, use a separate local scratch checkout with the
same private sources and saved models. analyzeLossExperiment and
analyzeMixedLoss regenerate their inference artifacts from the existing fits;
the latter creates a nested unique output directory. No dense or sparse fit
is needed. In that scratch checkout runReadoutLS('preflight') performs the
read-only real-data preparation plus synthetic checks and creates prepared.mat
from the restored mixed inference and saved October data. The function refuses
to run alongside an existing fit_started.mat or prepared.mat: use an isolated
scratch copy without copied generated readout run folders, never remove guards
or delete the original local study. It returns a unique folder; retain that
path and map it explicitly when using the historical saved model provenance.
Do not call its 'fit' mode to recover a feature cache.

The saved readout model and predictPNNN can regenerate its full inference
from that private Z, normalization and r. analyzeReadoutLS computes the private
amplitude ordering from the capture; its aggregate CSVs are already public.
The hidden continuation final_model.mat likewise permits inference without
training, using the same cached Z and r. analyzeHiddenContinuation documents
the metric calculation and requires the private LS inference/cache/order.
Old absolute provenance paths and unique run folders must be mapped to the
local restored archive in scratch analysis, not silently edited in the saved
scientific artifacts. Legacy root-cause analysis can be regenerated with its
diagnostic script and private sources, but public aggregate CSVs already
provide its reported results. These are recovery instructions only: no such
procedure, training, hardware access or CFR was executed for publication.

## Publication checks

The user explicitly authorized preserving existing formatting warnings (trailing
spaces and final blank lines) without editing historical artifacts. A CRLF-aware
check identified 185 trailing-space warnings and two final-blank-line warnings.
The repository already tracks MAT files through sergi_pniq_dpd/.gitattributes
and Git LFS. This existing configuration is retained for audited public MAT
artifacts only; none of the seven excluded files is staged or uploaded to LFS.
No LFS configuration was introduced or changed by this publication.
