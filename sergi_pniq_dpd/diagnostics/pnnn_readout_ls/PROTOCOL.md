# Frozen P310 readout LS protocol

Declared before the real fit, 2026-11-04. Exactly one fit of each output is
authorized as one experiment. No dense training, Adam, new pruning, alpha
search, regularization, hardware, CFR or production changes.

Use the October mixed alpha=0.5 model from the documented run, verify its
experimental/protocol/inference consistency and reproduce its saved prediction
exactly. Verify centered data against the relocated October raw capture.
Use original identification indices, masks and normalization unchanged.

Extract sigmoid1 through predict on the saved network, with the original
normalized input and default inference settings. Verify the final output
against its reconstruction from those activations before replacing weights.
Promote these fixed activations and the original normalized targets to double.
For each output use only mask-permitted hidden features and a final bias column.

Solve by an economy SVD A=U*S*V', using
tau=max(size(A))*eps(max(diag(S))) and retain singular values greater than tau.
Use beta=V_r*((U_r'*target)./s_r). No normal equations are formed to solve.
Report rank, raw and column-L2-scaled condition, all singular values, and
normal-equation residuals. No tolerance is selected on development data.

The objective is sum_c w_c*||A_c*beta_c-t_c||^2/(2*N), with the stored
positive alpha=0.5 weights. Each constant w_c cancels from its independent
normal equation, so no weighted alternative fit is necessary.

Keep hidden weights/biases, all masks, feature processing, graph, normalization
and state exactly unchanged. Insert only the 23 allowed output weights and
two output biases, cast to their original single precision. Require all 736
pruned weights to remain exactly zero and all 310 active parameters nonzero.
Save both double solutions and the actual single-precision model. Quantify
coefficient rounding, frozen-feature prediction rounding, and actual inference.

Preflight gates: synthetic known-solution SVD coefficient error <1e-10;
double normal-equation relative residual <1e-10; manual normalized-output
and restored complex-prediction relative L2 <1e-6; exact saved prediction,
mask, source, hidden-parameter and normalization identity where applicable.
Synthetic sigmoid comparison uses 1e-6 maximum absolute error. Expected
double-to-single coefficient rounding is bounded by eps(single)*abs(beta).
The real single inference loss must not exceed the baseline beyond the
explicit residual perturbation bound 2*||e||*||delta||/N+||delta||^2/N,
weighted by w_c/2 and including baseline and refitted forward-rounding terms.
Add 100*eps*max(1,baseline loss) for double reduction arithmetic. Record the
observed bounds instead of silently allowing a fixed loss increase.

Evaluate historical, mixed, mixed+LS and PN-IQ on identification, development
complement and the complete record, using the prior metric definitions.
Reuse the same sorted input-amplitude deciles and verify their saved baseline
boundaries and metrics. No new spectral or temporal sweep is planned.

Predeclared practical criterion: development NMSE gain >=0.10 dB and physical
Q-MSE increase <=10% versus mixed. Report outcomes regardless of this criterion.
It is not a significance test, independent validation or RF performance claim.

runReadoutLS('preflight') saves validated data to a unique directory without
fitting real coefficients. runReadoutLS('fit',folder) solves the real problem
once and saves immediately, guarded by fit_started.mat and readout_model.mat.
If analysis is interrupted, analyzeReadoutLS(folder) uses the saved model;
never remove the fit guard or rerun the real fit to regenerate analysis.
