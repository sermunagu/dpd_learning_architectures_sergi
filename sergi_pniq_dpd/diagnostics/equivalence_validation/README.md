# Extended scientific equivalence validation

This directory is an isolated diagnostic, not a production integration.
See REPORT.md for the completed results and their scope.

`runExtendedValidation.m` performs only four new accelerated fits: P20, P70,
P290 and P500, using the immutable saved dense source and 164 fixed epochs.
It calls the previously validated `../session_acceleration/sessionPrunePNNN.m`
helper. No dense training, full sweep, hardware calls or production writes occur.
Each invocation creates a unique output directory. Each fit is saved before
analysis so an analysis failure never requires repeating completed training.

`analyzeExtendedValidation.m` uses saved fits and inference only. It compares
the four new networks and the existing P100/P310/P400 accelerated networks with
the original scientific checkpoints. To reproduce analysis without training:

```matlab
addpath('sergi_pniq_dpd/diagnostics/equivalence_validation');
here = fileparts(which('analyzeExtendedValidation'));
out = fullfile(here, 'tp140925cd_b795_4d9a_9dd3_c2bcb8fb7af6');
analyzeExtendedValidation(out);
```

Analysis CSV files in that diagnostic directory are regenerated. The saved
accelerated fits and scientific checkpoints are never overwritten by analysis.
The full training command below is for explicit future reproduction only;
it is not needed to recover the completed results:

```matlab
runExtendedValidation
```

The acceptance thresholds were specified before running: prediction relative
L2 error strictly below 1e-5 and absolute full-signal NMSE difference strictly
below 1e-4 dB, with exact masks and pruned zeros. Active-parameter counts and
RNG identity are also required. Evaluation-set metrics, network state, all zero
locations, weight differences, rankings and operating-point sensitivity are
reported as additional checks. Relative L2 means norm(new-old)/norm(old),
computed in double from the stored values; it is not an elementwise ratio.

All auxiliary files can be removed by deleting this directory. Existing
`session_acceleration` evidence remains separate. No production file depends
on either diagnostic directory.
