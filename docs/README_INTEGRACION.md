# Research DPD: single budgets and RF sweeps

Run from the parent repository in MATLAB R2026a with Deep Learning Toolbox
and Signal Processing Toolbox. main_3 adds optional index selection; RF safety,
CFR and instrument calls remain unchanged.
Both `results/experiment<ts>.mat` and `results/experiment<ts>_xy.mat` must exist.
The latter contains finite vectors `x=u`, `y=x_ILC` of equal length.

## Combined export and laboratory index selection

```matlab
filenamedate = '20261023T102742'; % Actual capture timestamp.
dpd_mode = 'sweep';
dpd_export_mode = 'combined';
dpd_parameter_grid = 20:10:500;
clear dpd_sweep_directory      % Only for NEW training.
main_2_sergiDPD
```

For an existing sweep, set dpd_sweep_directory to its saved run folder instead
and clear dpd_parameter_grid to adopt its grid. No training occurs if all
required bundles exist. Combined mode always exports the full sorted grid,
ignoring dpd_rf_parameters. Only one format is produced per invocation.
The default remains dpd_export_mode='per_budget'; single mode is unchanged.

Output: `results/experiment<ts>_xy_execution_sergi_sweep.mat` (-v7.3), with
comparison_type='sergi_sweep', dpd, export_info and index_map. The table contains
Index, P, ModelType and Checkpoint; dpd fields remain modeltype and yvalmod.
For 20:10:500 there are 147 entries: increasing P, then GMP-DOMP, PN-IQ-GMP,
PNNN. Thus 1:3=P20, 4:6=P30, 88:90=P310 and 145:147=P500. For another grid,
consult index_map rather than assuming these positions.

In the instrument session with the matching timestamp and connected TRx:

```matlab
dpd_comparison_type = 'sergi_sweep';
clear dpd_n_regressors
dpd_indices = 89;             % PN-IQ-GMP P310 for the full grid.
main_3_testDPD
% Before running main_3 again, alternatives are:
% dpd_indices = 88:90;         % The three P310 models.
% clear dpd_indices           % Every signal in the combined file.
```

Indices must be unique, positive, finite numeric integers within the original
loaded struct. Order is preserved. Empty/absent dpd_indices retains all signals.
Selection occurs before the optional support-size filter and all RF safety
checks. Keep dpd_n_regressors cleared for these research exports. The same
indices apply separately to each selected execution file.

Results, safety CSVs and failed-capture paths include tags such as
`sergi_sweep_idx89` or `sergi_sweep_idx88-90`. Long irregular selections use a
SHA-256 index tag to keep filenames short. Final measurement files save
selected_indices relative to the original execution struct. Different ordered
selections have different names; repeating the SAME selection retains the
previous measurement overwrite behavior.

When both formats coexist, dpd_comparison_type='sergi_sweep' selects ONLY the
exact combined file. An exact per-budget name still selects that file. Without
a group filter main_3 processes all discovered files, so set the group explicitly.
To export per-budget files instead, set dpd_export_mode='per_budget' and use
the subset interface below. Neither format deletes existing files of the other.

Existing combined exports are preserved only after provenance, index map and
recomputed signals match exactly; conflicts fail. Publication uses a staged MAT
file. Checkpoints survive export interruption. Use one exporter per timestamp;
there is no concurrent-session lock.

Memory: the combined struct is preallocated and filled three signals at a time.
Verification retains one stored combined struct plus one inferred triplet.
Prior workspace dpd values are released before generating/loading, and main_3
releases its unselected load reference. MATLAB still loads the full struct:
491520 samples at 49 budgets require about 0.90 GiB for the complex arrays
alone (double/double/single), plus MATLAB and inference/training overhead.

### Combined-mode verification (MATLAB R2026a, 2026-10-23)

A real synthetic sweep [20 30 310 500] on 8192 complex samples exported 12
combined signals. Each matched direct inference and the per-budget export with
isequal. Tests passed for sorted order, map, v7.3 loading, existing-file rejection,
byte-identical reuse and single-mode compatibility. Only a temporary copy used
one dense/fine-tuning epoch and disabled figures; scientific source was unchanged.

The exact discovery and selection/preflight blocks of main_3 were tested without
executing the full script or hardware setup. Combined/per-budget coexistence
selected only the exact combined file. A separate 147-entry synthetic fixture
verified indices 89, 88:90 and all, distinct output tags, invalid-index rejection
and the actual safety function receiving only selected signals. An unselected
NaN did not enter that preflight; selecting all detected it. The long-tag path
also passed. This was not a full 49-budget training or RF experiment.

Static analysis found no messages in main_2 or select_dpd_indices; main_3 retains
its pre-existing global/unused/suppression messages. Source hashes verified no
changes to research algorithms, configurations or RF safety/CFR. Production
checkpoints were not modified.
External test scripts, logs and synthetic files were cleaned after verification.

## Single budget (default)

```matlab
filenamedate = '20261023T102742'; % Use the actual capture timestamp.
dpd_mode = 'single';
dpd_single_P = 310;
main_2_sergiDPD
```

Omitting dpd_mode defaults to single; omitting dpd_single_P defaults to 310.
The output is `results/experiment<ts>_xy_execution_sergi_p310.mat`.
An existing single output is rejected before training. Sweep settings are
ignored in single mode. Supported budgets are even integers from 20 to 500.

## Train the complete sweep once

```matlab
dpd_mode = 'sweep';
dpd_export_mode = 'per_budget';
dpd_parameter_grid = 20:10:500;
dpd_rf_parameters = [100 200 310 400 500];
clear dpd_sweep_directory
main_2_sergiDPD
```

The existing `runDPDSweep` trains the entire grid, with shared linear DOMP
paths and one definitive dense PNNN source followed by independent pruning
and fine-tuning. No scientific configuration is changed by the integration.
To export every point, use `clear dpd_rf_parameters` (or set it to []).
For a new run, an empty training grid means 20:10:500. RF budgets must be a
subset of the training grid. Duplicate budgets are removed and sorted.

Scientific outputs stay in `sergi_pniq_dpd/results/dpd_sweep/<run>/`.
The script prints the run directory; it is also returned as
`dpd_sweep_result_directory`. Save that path for subsequent exports.
`runDPDSweep` prints its directory before expensive fitting, so an interrupted
run can be resumed even if main_2 did not return its output variables.

## Export more budgets without training again

```matlab
dpd_mode = 'sweep';
dpd_export_mode = 'per_budget';
dpd_sweep_directory = fullfile(pwd, 'sergi_pniq_dpd', 'results', ...
    'dpd_sweep', '<saved-run-directory>');
clear dpd_parameter_grid       % Adopt the saved training grid.
dpd_rf_parameters = [200 310];
main_2_sergiDPD
```

The current `_xy` samples, original DC means and optional fs must match
`experiment.mat` in the saved run exactly. A copied identical capture is
allowed; a different capture with the same timestamp is rejected. Each
bundle must have the saved provenance, matching P and three reported real
parameter counts. An explicitly supplied training grid must equal the saved
grid. To start a new run later, clear dpd_sweep_directory explicitly.

If all requested bundles exist, they are loaded directly: no training, sweep
selection, figure export or checkpoint rewriting. If a requested bundle is
missing, `runDPDSweep(savedDirectory)` resumes using its existing checkpoints
and original configuration; it can complete other missing points in that run.
The integration does not extend a saved grid or silently reuse another run.
A missing final bundle can be reconstructed from existing linear/PNNN points
without training. Missing fitting checkpoints may require further training.

## Execution files and traceability

Each selected P creates an independent file, for example:

```text
results/experiment<ts>_xy_execution_sergi_sweep_p0310.mat
```

It contains `comparison_type='sergi_sweep_p0310'`, the complete `dpd` struct,
and a separate `export_info` struct with P, checkpoint path and capture path.
`dpd_exports` lists all selected execution paths. The compatibility variables
`modelFile`, `dpd`, `comparison_type`, `executionPath` describe the last export.

Every file has exactly three entries in this order:
`Complex_GMP_DOMP_P310`, `PN_IQ_GMP_P310`, `PNNN_P310` (with the selected P).
Each yvalmod is obtained by applying its saved bundle to the selected capture,
as a full-length finite complex column. Linear outputs remain double and
PNNN remains single. Historical DC removal and periodic memory remain intact;
no extra normalization, rescaling or CFR is applied. No n_regressors field is
added: 310 real parameters are not 310 regressors.

Fresh runs reject collisions before training. Explicit sweep reuse can keep
an existing output only when its provenance, group and recomputed signals
match exactly. Mismatches and legacy outputs without export_info are rejected;
archive such files deliberately if replacement is intended. Exports are
written to a temporary MAT file then moved into place, so interrupted saves
do not publish incomplete groups. Already completed groups remain reusable.
Use one exporter per timestamp: there is no lock between concurrent sessions.
If a checkpoint was moved, existing export_info paths may no longer match;
archive old execution files deliberately before exporting from the new path.

## RF measurement in the original instrument session

Keep the connected TRx and the original session variables filenamedate, fs,
info_signal, usw, fc and Lout. The timestamp must match the training capture.
Measure all currently exported sweep files for this timestamp:

```matlab
dpd_comparison_type = 'sergi_sweep';
clear dpd_n_regressors
main_3_testDPD
```

Measure one budget:

```matlab
dpd_comparison_type = 'sergi_sweep_p0310';
clear dpd_n_regressors
main_3_testDPD
```

For single mode, use `dpd_comparison_type='sergi_p310'` instead.
Without a combined file, the sweep prefix selects matching per-budget files,
not just the current dpd_rf_parameters selection. main_3 uses exact matches
first, otherwise the `<prefix>_` rule. A combined exact `sergi_sweep`
group takes precedence over the individual budget groups.

main_3 preflights each file as one group. One unsafe signal stops that group
and subsequent measurements; earlier groups may already have been measured.
All RF safety limits and CFR are unchanged. No unsafe signal is bypassed.

If the driver requires R2024a, train in R2026a and return to the existing
R2024a instrument session. The v7.3 execution files contain numeric signals
and structs, not dlnetwork objects. R2024a loading has not been tested here.

## Previous per-budget audit

Hardware-free validation completed on 2026-10-23 in MATLAB R2026a.
Full 49-point training on laboratory data and RF validation are separate lab
work. The synthetic test uses shorter epochs only in an external temporary
copy; production epochs, algorithms and configuration remain unchanged.

Verified in an external temporary project with 8192 complex synthetic samples:

- Default single P310 trained successfully and matched the previous entry point
  sample for sample (`isequal`), including the original numeric classes.
- The real shared sweep trained [20 100 310], generated all three bundles,
  and initially exported only [20 310]. Epoch budgets were reduced to one
  dense/fine-tuning epoch in the temporary copy; production settings unchanged.
- Each exported dpd matched direct applyDPDModels inference from its checkpoint;
  file/group/model labels, three complex finite columns and lengths were checked.
- Reuse added P100 and retained existing export bytes. Training entry points
  were replaced by errors in the temporary test copy: no training was called.
- Removing the P100 bundle and resuming reconstructed it from existing points
  without calling the disabled training entry points. Existing exports retained
  identical bytes and matched recomputed inference.
- The exact file-selection block and filename parser from main_3 selected three
  groups for sergi_sweep and one for sergi_sweep_p0310. No hardware code ran.
- Existing single exports, invalid RF subsets, odd budgets, a changed capture
  and a corrupted existing export were rejected.
- The caller's path was restored on success/failure; the two active toolboxes
  resolved their intended functions. checkcode reported no issues for main_2.
- Dependency resolution found no hardware dependency for the export entry.
- Source hashes confirmed that every pre-existing MATLAB file other than
  main_2_sergiDPD remained unchanged, including runDPDSweep, trainDPD,
  applyDPDModels, configuration, main_1, main_3 and the RF safety checks.

The first independent-inference test needed a correction to its temporary
path setup; the resumed test passed using the already trained checkpoints.
All test scripts, logs, models and synthetic captures were removed from the
external temporary directory after verification. No test artifacts were added
to this repository. No commits or push were made.

Remaining lab checks: full-budget training on the actual capture, storage and
runtime for 49 budgets (147 signals if all are exported), R2024a MAT loading
if used, and RF safety/measurement. Default figure export and long-run restart
at every possible interruption point were not exercised; the synthetic copy
suppressed figures. Existing runDPDSweep checkpoint and figure behavior was
preserved. A sparse pilot grid does not support operating-point selection;
that expected diagnostic does not prevent export.
