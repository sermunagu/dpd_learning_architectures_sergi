# AGENTS.md

Guidance for AI coding agents (and people) working on this repository.
Read [README.md](README.md) first: it describes the three-step procedure,
the configuration and the files produced.

---

## 1. Rules that always apply

1. **The main scripts drive real hardware** (ADRV9029 board and a Doherty
   PA). Do not run `main_1_learnDPD`, `main_3_testDPD` or any function that
   talks to the board (`connectADRV`, `reconnectADRV`, `measureADRV`,
   `transmitADRV`, `disableRFADRV`, `shutdownADRV`, `ADRV902x`) unless the
   user explicitly asks for it. Tests must never touch the hardware.
2. **Keep the safety checks.** Every `measureADRV` call in step 1 is preceded
   by `check_tx_safety(xCFR, maxRMSx, maxPEPx)`; step 3 runs
   `check_dpd_signal_safety` before transmitting a group. Do not remove them,
   bypass them or relax their limits (`maxRMSx`, `maxPEPx`,
   `dpd_safety_*`, the 0 dBFS check of `measureADRV`, the 15 dB CFR) unless
   the user asks for that specific change. A new code path that transmits
   must get the same protection.
3. **Do not write test data into `results/`.** Use a temporary folder
   (`tempname`) with its own `results/` subfolder.
4. **Do not change numerical results silently.** For example,
   `model_gmp_generate_X` must keep producing the same matrix (column order
   included); refactors are checked against the previous version with
   `isequal`.
5. Code, comments, messages and documentation are written in **English**
   (the user usually talks in Spanish).

---

## 2. Running and testing without hardware

MATLAB R2024a is installed on the lab PC:

```
"C:\Program Files\MATLAB\R2024a\bin\matlab.exe" -batch "<commands>"
```

Put anything longer than one line in a script file and call it with
`run('<path>')`: quoting inside `-batch` (especially from PowerShell) breaks
easily.

| Check | How |
|---|---|
| Static analysis | `checkcode('<file>')` |
| Dependencies and toolboxes | `matlab.codetools.requiredFilesAndProducts('<file>')` with the same `addpath` calls as the script |
| Signal generation | `waveform_id = 8; config_signal_master_5waveforms; [usw, ~, info_signal] = genera_5GNR_multicarrier_v5(info_signal); u = clipping_PAPR_ICF(usw, 8, mask, 5);` |
| Learning updates (ILC / DLA / ILA) | Reproduce the update lines with a synthetic PA (e.g. a Wiener model with Saleh-like AM/AM and AM/PM) and check the NMSE of `y/g0` against `u` over the iterations |
| Step 2 | Copy `main_2_testexperiment.m` and the functions it needs to a temporary project, create fake `experiment<ts>.mat` and `experiment<ts>_xy.mat`, run it and load the execution file as `main_3_testDPD` does |
| Step 3 logic | Extract the relevant lines of `main_3_testDPD.m` and `eval` them on fake experiments (never run the whole script) |

**Accepted `checkcode` warnings** (do not "fix" them):

- `INV(A)*b can be slower and less accurate than A\b`: the full formula is
  intentional (see below).
- `This named argument will override a previous one` in the `exp_config =
  struct(...)` call: false positive, `G`/`g`, `Gc`/`gc` and `G0`/`g0` are
  different fields.
- `global TRx`, unreachable code behind constant flags, variables that
  "might be unused" because they are consumed by the helper scripts.

---

## 3. Code style

- **Least squares:** write the full formula, not the backslash operator.
  With normalized columns, as in the DLA update:

  ```matlab
  normU = vecnorm(U);
  Un = U*diag(normU.^-1);
  dw = diag(normU.^-1)*(inv(Un'*Un)*Un')*e;
  ```

- **Indentation:** tabs in `main_1_learnDPD.m`, 4 spaces everywhere else
  (`ADRV902x.m` is vendor code and mixes both).
- **Line endings differ from file to file**, even inside the same folder:
  most files are CRLF, but for example `main_2_testexperiment.m`,
  `main_3_testDPD.m`, `generate_learning_report.m`, `meas2figure.m` and
  `check_dpd_signal_safety.m` are LF, and `store_data_and_show_performance.m`
  and `update_figures.m` mix both. Keep the line endings of the file you edit
  (check the bytes before and after; an editor that writes LF must convert
  back when the file is CRLF). New files use CRLF.

- Use ASCII in new code and comments.
- **One-line calls for cross-cutting checks**, e.g.
  `check_tx_safety(xCFR, maxRMSx, maxPEPx); % Stops before transmitting an unsafe signal`.
  If a check needs more than one line, write a function in `toolbox/`.
- New helpers go to `toolbox/` when they do not depend on the hardware and to
  `toolbox_ADRV/` when they do. Every function starts with a help block
  (purpose, inputs, outputs).
- File names do not carry dates: git keeps the history. When a file is
  renamed, search the whole repository for the old name (help texts and
  comments of other scripts included) and update every reference.
- Code that is no longer used goes to a `hist/` subfolder of its toolbox
  (not on the MATLAB path) instead of being deleted, after checking with
  `requiredFilesAndProducts` and a text search (for `eval`, `run`, `feval`
  and names built at run time) that nothing calls it.

---

## 4. Data and workspace contracts

### Configuration of step 1

- New configuration variables are defined in the "Experiment configuration"
  section of `main_1_learnDPD.m`, with a comment, **and added to the
  `exp_config = struct(...)` call** so that they are saved with the
  experiment.
- `config_signal_master_5waveforms` sets `RMSin = 0` and `PAPRd = 12` at the
  end; `main_1_learnDPD` defines `RMSin` after calling it. Keep that order.

### Helper scripts

`store_data_and_show_performance.m` and `update_figures.m` are **scripts**,
not functions: they read and write the caller's workspace.

- They read: `ACPR`, `EVM`, `NMSE`, `y`, `x`, `u`, `xCFR`, `measdata`,
  `Gin`, `Lout`, `G0`, `g`, `fs`, `filenamedate`, `meas`, `meas_out` and the
  anonymous functions of `inline_functions` (`dBm`, `PAPR`, `dBminst`).
- Set `meas.descr` and `meas.mu` before calling them; the rest of `meas` is
  filled by `store_data_and_show_performance`, which appends it to
  `meas_out`.
- Every entry of `meas_out` must have the same fields (struct array
  concatenation).

### `meas_out` entries

`descr`, `mu`, `y`, `x`, `u`, `xCFR`, `performance` (`ACPR`, `EVM`, `NMSE`),
`data` (output of `measure_power_supplies`, with `I1` and `V1`), `w`, `Gin`,
`Lout`, `Pin`, `Pout`, `PAPRx`, `PAPRxCFR`, `Gdpd`, `Gsist`, `Gavg`, `Gc`,
`G0`.

### Last measurement with DPD

`meas_out(end)` is the final measurement **without** DPD when
`measureWithoutDPDAtEnd` is true. Anything that needs the last learned
signal must use

```matlab
iLastDPD = length(meas_out) - measureWithoutDPDAtEnd;
```

(step 1: deletion of intermediate signals and `_xy` file; step 3: reference
of the preflight, through `exp_config.measureWithoutDPDAtEnd`, with a
fallback for old experiments that lack the field).

### Files between steps

| File | Producer | Consumer | Contents |
|---|---|---|---|
| `experiment<ts>.mat` | step 1 | steps 2 and 3, report | `meas_out`, `exp_config`, `filenamedate`, `info_signal` |
| `experiment<ts>_xy.mat` | step 1 | step 2 | `x` = `u` (model input), `y` = learned PA input (model target), `fs`, `info_signal`, `exp_config`, `description` |
| `experiment<ts>_xy_execution_<group>.mat` | step 2 | step 3 | `dpd` (`modeltype`, `yvalmod`, optional `n_regressors`), `comparison_type` |
| `experiment<ts>/performance_results.xlsx` | `meas2figure` | report | One row per measurement |

Step 3 also needs, in the MATLAB session: `filenamedate`, `fs`,
`info_signal`, `usw`, `fc`, `Lout` and the connected `TRx` in the base
workspace (read with `evalin('base', 'TRx')`).

---

## 5. Pitfalls

- `measureADRV` calls `measure_power_supplies()`, a lab function that is not
  in the repository: `measureADRV` fails without it.
- `model_configuration_B` turns off `MATLAB:nearlySingularMatrix`, so an
  ill-conditioned least-squares solve does not warn. The 0 dBFS check of
  `measureADRV` lets NaN through (`NaN > 0` is false); `check_tx_safety` is
  what stops it.
- `CFR_hard` restores the average power after clipping: it cannot fix an
  excessive average power, and the output PAPR is slightly above the target.
- `maskerr` (error mask of the ILC) is only defined for waveform 1; for the
  other waveforms it is empty and the error is not filtered.
- ILA with `gainMode = 'average'` diverges when the PA is in deep
  compression (verified in simulation); `'compressed'` works.
- `model_gmp_generate_X` always adds the conjugate terms for `Ka == 0`
  (`model.cs` is ignored) and removes the DC of its inputs.
- `generate_learning_report` looks for the PNG files whose names end in
  `_DPD_AMAMn`, `_DPD_AMAM`, `_DPD_GAM` and `_Spectrum_acc`; they come from
  the figure names of `update_figures`. Renaming those figures breaks the
  report.
- `genera_5GNR_multicarrier_v5` has its own local function `espectro`; the
  file `toolbox_signalgen/hist/espectro.m` is not used.
- `toolbox_signalgen/hist/` and `external/matlab2tikz/` are not used by the
  main scripts.

---

## 6. Git

- `results/` and `output/` are not tracked (`.gitignore`).
- `external/matlab2tikz` is a submodule of the upstream repository; do not
  edit it in place.
- `.gitattributes` sets `* -text`: files are stored byte for byte, so git
  does not convert their line endings (the lab PC has `core.autocrlf=true`).
- Remote: `https://github.com/juananbecerra/dpd_learning_architectures`
  (private). On the lab PC, git reaches GitHub only with the Windows
  certificate store: `git -c http.sslBackend=schannel ...`.
- Commit messages in English, in the imperative mood.
