# DPD learning architectures

MATLAB code for the laboratory procedure used to linearize an RF power
amplifier (a Doherty PA at 2.6 GHz) with digital predistortion (DPD). The PA
is driven and observed through an Analog Devices ADRV902x transceiver
(ADRV9029 evaluation board). The procedure has three steps:

1. **Learn** the PA input that linearizes the PA, in closed loop with the
   hardware, using one of three learning architectures: iterative learning
   control (ILC), direct learning (DLA) or indirect learning (ILA).
2. **Model** a DPD offline that reproduces that signal from the original one
   (template script; a GMP least-squares model is included as an example).
3. **Test** the DPD signals on the hardware, after a safety preflight.

```
main_1_learnDPD ──► results/experiment<ts>.mat        (all the measurements)
                    results/experiment<ts>_xy.mat     (u -> x pair for modeling)
                    results/experiment<ts>/           (figures, table, PDF report)
        │
        ▼
main_2_testexperiment ──► results/experiment<ts>_xy_execution_<group>.mat
        │
        ▼
main_3_testDPD ──► results/experiment<ts>_DPD_<group>.mat
                   results/experiment<ts>_DPD_safety_<group>.csv
```

`<ts>` is the experiment timestamp (`filenamedate`, `yyyymmddTHHMMSS`), set by
`main_1_learnDPD`. The three scripts are meant to run **in the same MATLAB
session**: step 3 reuses the connected `TRx` object and several workspace
variables left by step 1.

---

## Contents

- [Requirements](#requirements)
- [Repository layout](#repository-layout)
- [Step 1: main_1_learnDPD](#step-1-main_1_learndpd)
- [Step 2: main_2_testexperiment](#step-2-main_2_testexperiment)
- [Step 3: main_3_testDPD](#step-3-main_3_testdpd)
- [Results folder](#results-folder)
- [Safety](#safety)
- [Conventions](#conventions)
- [Known limitations](#known-limitations)
- [Third-party code](#third-party-code)

---

## Requirements

**Software**

| Item | Used by | Notes |
|---|---|---|
| MATLAB R2024a | all | Tested with R2024a Update 6 |
| Signal Processing Toolbox | steps 1 and 3 | e.g. `xcorr` and `findpeaks` in `full_sync_5G` |
| Communications Toolbox | steps 1 and 3 | Signal generation and analysis functions |
| pdflatex (e.g. MiKTeX) | step 1 | Only for the PDF report |

The tutor's step 2 only needs base MATLAB. The research alternative,
`main_2_sergiDPD`, uses MATLAB R2026a, Deep Learning Toolbox and Signal
Processing Toolbox. See [integration instructions](docs/README_INTEGRACION.md).

**Hardware and lab software (not included in this repository)**

- ADRV9029 evaluation board, reachable at `192.168.1.10`.
- ADRV9025 Transceiver Evaluation Software from Analog Devices (GUI 6.4.0.17,
  DLL 6.4.0.14). It provides the .NET assemblies (`adrvtrx_dll`,
  `adrv9010_dll`) used by `toolbox_ADRV/ADRV902x.m`.
- `measure_power_supplies()`: lab instrument function called by
  `measureADRV` after every capture. It must return a structure with at
  least the fields `I1` (A) and `V1` (V) of the PA supply, used for the PAE.
  It is not part of this repository and must be on the MATLAB path.
- Optional power supply helpers referenced in comments of `main_1_learnDPD`
  (`fuenteDC`, `fuente_Doherty`, `fuenteK_monitorI1`), also not included.

**Getting the code**

`external/matlab2tikz` is a git submodule. Clone with

```
git clone --recursive https://github.com/juananbecerra/dpd_learning_architectures.git
```

or run `git submodule update --init` in an existing clone. The main scripts
do not need it.

**Working folder**

Run the scripts from the repository root. They use relative paths
(`results/`, `toolbox/`, ...) and `main_2`/`main_3` `cd` to the root
themselves.

---

## Repository layout

| Path | Contents |
|---|---|
| `main_1_learnDPD.m` | Step 1: closed-loop learning (ILC / DLA / ILA) on the hardware |
| `main_2_sergiDPD.m` | Research step 2: single budget or shared sweep; see [integration guide](docs/README_INTEGRACION.md) |
| `sergi_pniq_dpd/` | Research algorithms, offline training, sweeps and historical data |
| `main_2_testexperiment.m` | Step 2: template for offline DPD modeling |
| `main_3_testDPD.m` | Step 3: measurement of the DPD signals on the hardware |
| `confset/` | Configuration scripts: power helpers and GMP model orders |
| `toolbox/` | Platform-independent processing, figures, report, safety check |
| `toolbox_ADRV/` | ADRV902x control, capture, synchronization and ACPR |
| `toolbox_signalgen/` | 5G NR waveform generation and analysis |
| `toolbox_signalgen/hist/` | Legacy signal generation code, not on the path |
| `external/matlab2tikz/` | Third-party figure export, git submodule (not used by the main scripts) |

### confset

| File | Description |
|---|---|
| `inline_functions.m` | Anonymous functions `dBm`, `dBminst`, `PAPR`, `maxdBm`, `scale_dBm` (100 Ω reference) |
| `model_configuration_B.m` | GMP model used by DLA, ILA and the step 2 example: `Ka = 0:2:12` (`La = 5`), `Kb = Kc = 2:2:6` (`Lb = Lc = Mb = Mc = 3`), periodic extension. Also turns off the `MATLAB:nearlySingularMatrix` warning |
| `model_configuration_A.m` | Smaller GMP model (`Ka = 0:2:6`, `La = 3`, ...) |

### toolbox

| File | Description |
|---|---|
| `CFR_hard.m` | Hard clipping CFR to a target PAPR, keeping the average power |
| `calculate_Gc.m` | Average gain `G`, gain `Gc` and phase `Phc` at the input peak; plots the instantaneous gain |
| `check_tx_safety.m` | Stops before transmitting a non-finite signal or one above the power limits |
| `model_gmp_generate_X.m` | Regression matrix of a GMP model (also FV/CVS with external builders) |
| `sel_indices.m` | Contiguous window of `perc` of the record around the peak of a signal |
| `store_data_and_show_performance.m` | Script: appends the current measurement to `meas_out` and updates the table |
| `update_figures.m` | Script: spectra and AM/AM-AM/PM figures, exported as PNG to the experiment folder |
| `meas2figure.m` | Performance table (figure and `performance_results.xlsx`) and NMSE plot |
| `generate_learning_report.m` | LaTeX/PDF report of an experiment |
| `spectrumest.m` | PSD estimation (Welch or FFT) |
| `getOrCreateFigure.m` | Reuses a figure by name |
| `medida2figure.m` | Legacy version of `meas2figure` (old field names) |

### toolbox_ADRV

| File | Description |
|---|---|
| `ADRV902x.m` | ADRV902x class (Analog Devices sample code): connection, transmit, capture |
| `connectADRV.m` / `reconnectADRV.m` | Create the global `TRx` object (profile 14, 122.88 MHz reference clock); `reconnect` skips the FPGA programming |
| `disconnectADRV.m`, `disableRFADRV.m`, `shutdownADRV.m` | Release the handler, disable RF, shut the board down over SSH |
| `measureADRV.m` | Transmits a waveform and captures the ORx (TX attenuation 10 dB, ORx gain 255) |
| `transmitADRV.m` | Transmission only, with selectable channel and attenuation |
| `full_sync_5G.m` | Coarse and per-cycle fine synchronization, cycle averaging |
| `ACPROFDM.m` | Multi-carrier ACPR and NMSE |
| `check_dpd_signal_safety.m` | Preflight of the step 3 signals against a reference |
| `validate_adrv_trx.m` | Checks the existing `TRx` object without reconnecting |

### toolbox_signalgen

| File | Description |
|---|---|
| `config_signal_master_5waveforms.m` | Configuration of the 8 test waveforms (see below), spectral masks |
| `genera_5GNR_multicarrier_v5.m` | 5G NR multi-carrier OFDM signal generation |
| `clipping_PAPR_ICF.m` | Iterative clipping and filtering to a target PAPR |
| `spectrumMask.m` | Ideal spectral shaping with a piecewise mask |
| `analiza_medidas_5GNR_v6.m` | EVM, ACPR and NMSE of a measured 5G NR signal |

---

## Step 1: main_1_learnDPD

Learns, iteration by iteration on the hardware, the PA input `x` that makes
the PA output `y` a scaled copy of the original signal `u`.

### Signal

`waveform_id` selects one of the 8 waveforms of
`config_signal_master_5waveforms` (all of them: 60 kHz subcarrier spacing,
256-QAM, 4 slots, NFFT 2048, sampled at 491.52 MHz):

| `waveform_id` | Carriers | Channel BW | PRBs | Offset |
|---|---|---|---|---|
| 1 | 1 | 5 MHz | 6 | 0 |
| 2 | 1 | 5 MHz | 6 | −77.5 MHz |
| 3 | 1 | 5 MHz | 6 | +77.5 MHz |
| 4 | 2 | 20 MHz each | 24 each | ±70 MHz |
| 5 | 2 | 80 MHz each | 107 each | ±40 MHz |
| 6 | 1 | 20 MHz | 24 | 0 |
| 7 | 1 | 50 MHz | 65 | 0 |
| 8 (default) | 1 | 100 MHz | 135 | 0 |

The generated signal `usw` is limited to 8 dB of PAPR with
`clipping_PAPR_ICF` and scaled to `RMSin` dBm; the result is the reference
`u`.

### Configuration (section "Experiment configuration")

| Variable | Default | Meaning |
|---|---|---|
| `fc` | 2.6e9 | Carrier frequency (Hz); `connectADRV(2600)` uses MHz |
| `Lout` | 62.6 | Output path loss (dB) applied to the captured signal |
| `Gin` | 48.8 | Gain from the baseband signal to the PA input (dB), used for `Pin` |
| `Ncycles` | 16 | Signal repetitions per capture (averaged by `full_sync_5G`) |
| `RMSin` | −22 | Average power of `u` (dBm) |
| `maxRMSx` | `RMSin + 3` | Safety limit: average power of the transmitted signal (dBm) |
| `maxPEPx` | `RMSin + 14` | Safety limit: peak power of the transmitted signal (dBm) |
| `gainMode` | `'average'` | Target gain `G0`: `'average'`, `'compressed'` or `'fixed'` |
| `Gfixed` | 63.5 | `G0` (dB) when `gainMode = 'fixed'` |
| `Niter` | 15 | Number of learning iterations |
| `DLmethod` | `'ILC'` | Learning architecture: `'ILC'`, `'DLA'` or `'ILA'` |
| `measureWithoutDPDAtEnd` | false | Adds a final measurement of `u` at the power of the last `x` |
| `deleteIntermediateSignals` | true | Removes the signals of the intermediate iterations before saving |
| `saveLastMeasurement` | true | Saves the `_xy` file for step 2 |
| `stopOnConvergence` | false | Stops when the ACPR changes less than `ACPRthreshold` |
| `ACPRthreshold` | 0.01 | Convergence threshold (dB) |

All of them are saved in `exp_config`.

### Iteration

For every iteration:

1. Predistorted signal `x` (see the table below) and hard CFR to 15 dB of
   PAPR (`xCFR`).
2. `check_tx_safety(xCFR, maxRMSx, maxPEPx)`: stops the script before
   transmitting an unsafe signal.
3. `measureADRV` (transmission and capture), `full_sync_5G` (synchronization
   and averaging of the `Ncycles` cycles), scaling by `Lout`.
4. Metrics: EVM (`analiza_medidas_5GNR_v6`), ACPR and NMSE (`ACPROFDM`).
5. Gains with `calculate_Gc(y, xCFR)`: average gain `G` and gain at the peak
   `Gc`. In the first iteration (without DPD) the target gain `G0` is fixed
   from `gainMode`:
   - `'average'`: `G0 = G`, average gain. The DPD has to expand the peaks to
     compensate the compression, which raises the peak power at the PA input.
   - `'compressed'`: `G0 = Gc`, gain at the compression point. The target is
     what the PA can deliver at the peak. `Gc` comes from a single sample, so
     it is noisy.
   - `'fixed'`: `G0 = Gfixed`.
6. Error `e = y/g0 − u`, filtered with the error mask `maskerr` of the
   waveform (only waveform 1 defines one; for the rest it is empty and the
   error is not filtered).
7. Update of the learning architecture.

| `DLmethod` | Predistorted signal | Update |
|---|---|---|
| `'ILC'` | `x = u − U_w` | `U_w ← U_w + mu·e`, with `mu = mu0·g0/g` |
| `'DLA'` | `x = u − U·w` | `w ← w + mu·Δw`, `Δw` = least squares of `e` on the GMP basis `U` of `u` (normalized columns) |
| `'ILA'` | `x = u − U·w` | Post-inverse trained from `yn = y/g0` to `xCFR` with the same structure (`xCFR = yn − Y·wpost`, `Y` = GMP basis of `yn`), then `w ← w + mu0·(wpost − w)` |

`g = 10^(G/20)`, `g0 = 10^(G0/20)` and `mu0 = 1`. With `mu = g0/g`, ILC and
DLA cancel the error in one step for the average gain; ILA uses `mu0` only as
damping, since the gain is already normalized by `g0`. The least-squares
solutions are written with the full formula `inv(A'*A)*A'`.

The GMP model of DLA and ILA is `confset/model_configuration_B.m`.

> In simulation with a strongly compressed PA, ILA with
> `gainMode = 'average'` diverges (the post-inverse is trained on a compressed
> `yn` and then evaluated on the larger peaks of `u`). Use
> `gainMode = 'compressed'` with ILA when the PA is driven into compression.

### Final measurement without DPD

With `measureWithoutDPDAtEnd = true`, after the loop `u` is scaled to the
average power of the last `x` and measured once more (same processing,
`mu = 0`). It is stored as the last entry of `meas_out`. The scripts locate
the last measurement **with** DPD as

```matlab
iLastDPD = length(meas_out) - measureWithoutDPDAtEnd;
```

### Outputs

- `results/experiment<ts>.mat`: `meas_out`, `exp_config`, `filenamedate`,
  `info_signal`. With `deleteIntermediateSignals = true`, the signals (`x`,
  `y`, `u`, `xCFR`) are kept only for the first measurement, the last one with
  DPD and the final one without DPD (if any); the metrics of every iteration
  are always kept.
- `results/experiment<ts>_xy.mat` (if `saveLastMeasurement`): pair for the
  DPD modeling of step 2, taken from the last measurement with DPD:
  - `x`: original signal `u` (DPD input)
  - `y`: PA input `x` found by the learning (DPD target)
  - `fs`, `info_signal`, `exp_config`, `description`
- `results/experiment<ts>/`: PNG figures, `performance_results.xlsx` and the
  PDF report (see [Results folder](#results-folder)).

---

## Step 2: main_2_testexperiment

Template for the offline DPD modeling. It:

1. Selects the experiment: `filenamedate` from the workspace (left by step 1)
   or, in a new session, the newest experiment with both the `.mat` and the
   `_xy.mat` files.
2. Loads the `_xy` file into the structure `xy` (so the session variables are
   not overwritten): `u = xy.x` (DPD input) and `xdpd = xy.y` (DPD target).
3. Runs the section **"DPD MODELING (fill in)"**, where each model to test is
   added as an entry of `dpd`:

   ```matlab
   dpd(end+1).modeltype = 'My model';
   dpd(end).yvalmod     = <DPD output for the whole signal u>;
   ```

   The example included fits a GMP (`model_configuration_B`) by least squares
   on the 10 % window around the peak of `|xdpd|` (`sel_indices`, `perc_id =
   0.1`) and applies it to the whole signal. It prints the NMSE on the
   identification window and on the whole signal.
4. Checks that every `yvalmod` is finite and has as many samples as `u`, and
   saves the execution file read by step 3.

**Output:** `results/experiment<ts>_xy_execution_<comparison_type>.mat`

| Variable / field | Description |
|---|---|
| `comparison_type` | Name of the group of signals (`'custom'` by default; set it before running) |
| `dpd(k).modeltype` | Name of the case, shown by step 3 |
| `dpd(k).yvalmod` | DPD signal to measure (column, same length as `u`) |
| `dpd(k).n_regressors` | Optional; only needed to filter with `dpd_n_regressors` in step 3 |

Several groups can be generated by running the script with different
`comparison_type` values.

---

## Step 3: main_3_testDPD

Measures on the hardware every DPD signal of the execution files of an
experiment.

**Before running**, in the MATLAB session of step 1 (the script checks it):

- `filenamedate` of a completed experiment,
- `fs`, `info_signal`, `usw`, `fc`, `Lout` in the workspace,
- the connected `TRx` object in the base workspace (it is reused, never
  reconnected).

**Optional filters and limits** (set before running):

| Variable | Default | Meaning |
|---|---|---|
| `dpd_comparison_type` | all groups | Measure only one group (exact name or prefix `<name>_`) |
| `dpd_indices` | all | Unique original signal indices to measure; adds a selection tag to output names |
| `dpd_n_regressors` | all | Measure only the signals with these support sizes |
| `dpd_safety_average_margin_dB` | 0.5 | Average power margin over the reference |
| `dpd_safety_peak_margin_dB` | 1.25 | Peak power margin over the reference |
| `dpd_safety_cfr_papr_limit_dB` | 15 | CFR PAPR applied before transmitting |

**Procedure for each group:**

1. The reference is the last measurement **with** DPD of step 1 (`xCFR` of
   `meas_out(iLastDPD)`); older experiments without
   `exp_config.measureWithoutDPDAtEnd` use the last measurement.
2. Safety preflight of all the signals of the group
   (`check_dpd_signal_safety`, evaluated after the CFR): finite values,
   average power ≤ reference + 0.5 dB, PAPR ≤ 15.05 dB, peak power ≤
   reference peak + 1.25 dB. If any signal fails, the script stops before
   transmitting anything of that group (and of the following groups).
3. For each signal: CFR, `measureADRV`, synchronization with `xCFR`,
   metrics, and storage in `meas_out` (the first entries are the first and
   the last DPD measurements of step 1). The target gain used for the table
   is fixed to `G0 = 65` dB.
4. If the post-processing of a capture fails, the capture is saved in
   `results/experiment<ts>_DPD_failed_capture_<group>_signal_<k>.mat` before
   rethrowing the error.

**Outputs:**

- `results/experiment<ts>_DPD_safety_<group>.csv`: preflight table.
- `results/experiment<ts>_DPD_<group>.mat`: `meas_out`, `comparisonType`,
  `runType` (saved at the end of each group).

---

## Results folder

```
results/
├── experiment<ts>.mat                          step 1, all the measurements
├── experiment<ts>_xy.mat                       step 1, u -> x pair
├── experiment<ts>_xy_execution_<group>.mat     step 2, DPD signals
├── experiment<ts>_DPD_safety_<group>.csv       step 3, preflight
├── experiment<ts>_DPD_<group>.mat              step 3, measurements
└── experiment<ts>/
    ├── performance_results.xlsx                table of every measurement
    ├── NN_<figure name>.png                    figures (update_figures)
    ├── experiment<ts>_report.tex
    └── experiment<ts>_report.pdf
```

`main_1_learnDPD` creates `results/` if it does not exist. The folder is not
tracked by git.

**Performance table** (`performance_results.xlsx`, rewritten after every
measurement by `meas2figure`): description, NMSE, ACPR, EVM, `RMSin`, `Pin`,
`Pout`, `RMSout`, PAPR before and after CFR, system gain, `G0`, DPD gain
(`Gdpd = dBm(x) − dBm(u)`), PA gain, `Gc`, system gain at the peak, supply
current, `mu` and PAE.

**PDF report:** `main_1_learnDPD` calls
`generate_learning_report(filenamedate, exp_config, info_signal)` at the end. It
can also be generated later, from the repository root:

```matlab
generate_learning_report('20261015T103000')   % loads results/experiment<ts>.mat
```

It needs `pdflatex` on the system path, `performance_results.xlsx` and the
PNG figures of the experiment folder.

---

## Safety

The scripts drive a real PA. Powers are expressed in dBm of the baseband
signal with a 100 Ω reference, **before** `Gin`.

**Step 1** (every transmission, including the final one without DPD):

| Protection | Where | Limit |
|---|---|---|
| Non-finite samples | `check_tx_safety` | No NaN / Inf |
| Average power | `check_tx_safety` | ≤ `maxRMSx` (`RMSin + 3` dBm) |
| Peak power | `check_tx_safety` | ≤ `maxPEPx` (`RMSin + 14` dBm) |
| PAPR | `CFR_hard` | ~15 dB (the average power is not limited by the CFR) |
| DAC full scale | `measureADRV` | Peak ≤ 0 dBFS, i.e. PEP ≤ −6.1 dBm with TX attenuation 10 dB |

**Step 3:** preflight relative to the last DPD measurement of step 1 (see
above) and the same 0 dBFS limit of `measureADRV`.

Notes:

- `check_tx_safety` and the step 3 preflight raise an error: the script
  stops and nothing is transmitted. In step 1 the experiment `.mat` is not
  saved in that case (`meas_out` stays in the workspace; the figures of the
  previous iterations are already exported).
- The 0 dBFS check of `measureADRV` does not detect NaN: that is the reason
  for the finiteness check of `check_tx_safety`.
- The limits of `check_tx_safety` must be adjusted to the ratings of the PA
  and the driver.

---

## Conventions

- Signals are complex baseband column vectors sampled at
  `fs = 491.52 MHz`.
- `dBm(x) = 10·log10(rms(x)²/100) + 30`; `PAPR(x) = 20·log10(max|x|/rms(x))`.
- `u`: reference (original) signal; `x`: PA input (predistorted);
  `xCFR`: what is actually transmitted; `y`: PA output referred to the PA
  output plane (`Lout` applied).
- The predistorter of DLA and ILA is `x = u − U·w`, with `U` the GMP basis of
  `u` (`model_gmp_generate_X(u, u, dpd_model)`).
- In the `_xy` file the names follow the modeling point of view: `x` is the
  model input (`u`) and `y` the model target (the learned PA input).
- Configuration flags are defined in the "Experiment configuration" section
  of `main_1_learnDPD` and saved in `exp_config`.

---

## Known limitations

- `main_1_learnDPD` has a `platform` switch (`'ADRV'` / `'RFSoC'`), but the
  loop always calls `measureADRV`, so only the ADRV platform works. The
  `toolbox_RFSoC` folder is not included.
- `measureADRV` always uses TX attenuation 10 dB and ORx gain 255 (they are
  documented as optional inputs, but the function only takes two arguments).
- The ACPR convergence check (`stopOnConvergence`) compares
  `ACPR(end/2)`; it assumes an even number of ACPR values.
- `measure_power_supplies` and the power supply helpers are lab functions
  outside this repository.
- `shutdownADRV` uses the factory credentials of the ADI board as defaults.

---

## Third-party code

- `toolbox_ADRV/ADRV902x.m`: sample class from the Analog Devices ADRV9029
  customer package (see its header).
- `toolbox_signalgen/spectrumMask.m`: by Kevin Chuang (Analog Devices).
- `external/matlab2tikz/`: [matlab2tikz](https://github.com/matlab2tikz/matlab2tikz),
  included as a git submodule and distributed under its own license
  (`external/matlab2tikz/LICENSE.md`).
