# PN-IQ-GMP

This folder contains a self-contained, simple PN-IQ-GMP implementation built
to be compared directly with the conventional GMP implementation.

## Files

```text
main_run_compare_gmp_pniq.m
```

Main executable experiment. It loads the copied INMMIC26 measurement from
`measurement`, selects 10% of the signal with `sel_indices`, trains GMP and
PN-IQ-GMP with DOMP up to 500 selected regressors/features, and saves CSV
tables, MATLAB figures, TikZ figures, PNG figures, and a PDF report.

```text
toolbox
```

Self-contained helper functions used by the main script.

```text
toolbox/model_gmp_domp_omp.m
```

Reference GMP model copied from `PAWR27/toolbox`.

```text
toolbox/model_pniq_gmp_domp_omp.m
```

PN-IQ-GMP model with the same basic interface:

```matlab
model = model_pniq_gmp_domp_omp(ymed, xmed, model);
```

It uses the same GMP basis configuration fields:

```text
Ka, Kb, Kc, La, Lb, Lc, Mb, Mc
```

and the same calculation modes:

```text
pinv
OMP
DOMP
matrix_only
```

```text
toolbox/run_compare_gmp_pniq_template.m
```

Minimal script showing how to run the same configuration with GMP and
PN-IQ-GMP.

The main experiment saves:

```text
results/nmse_sweep_gmp_vs_pniq.csv
results/selected_regressors_gmp_vs_pniq.csv
results/final_validation_nmse.csv
results/nmse_identification_sweep.png/.fig/.tex
results/nmse_full_signal_validation_sweep.png/.fig/.tex
results/report_gmp_vs_pniq.pdf
results/comparison_gmp_vs_pniq.mat
```

## PN-IQ Convention

The complex GMP dictionary `psi` is rotated sample by sample using the input
phase:

```matlab
rotation = conj(x) ./ abs(x);
y_tilde = rotation .* y;
psi_tilde = rotation .* psi;
```

The real PN-IQ dictionary is:

```matlab
Phi = [real(psi_tilde), imag(psi_tilde)];
```

Each selected PN-IQ feature has two real coefficients: one fitted against
`real(y_tilde)` and one fitted against `imag(y_tilde)`. Therefore, `Nmax`
counts selected PN-IQ features, while the real parameter count is
approximately `2*Nmax`.

## Autocontained Helpers

The folder also includes the helper functions required by the copied GMP
reference:

```text
toolbox/omp_domp.m
toolbox/normalized_regression.m
toolbox/delay_signal.m
toolbox/sel_indices.m
toolbox/matlab2tikz
```
