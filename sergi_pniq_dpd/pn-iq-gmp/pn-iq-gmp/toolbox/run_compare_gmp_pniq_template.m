%RUN_COMPARE_GMP_PNIQ_TEMPLATE Minimal comparison between GMP and PN-IQ-GMP.
%
% Define xmed and ymed in the workspace before running this script. Both must
% be complex column vectors with the same length.

thisDir = fileparts(mfilename('fullpath'));
addpath(thisDir);

clear modelGmp modelPniq

cfg = struct();
cfg.Ka = 0:2:12;
cfg.Kb = 2:2:12;
cfg.Kc = 2:2:12;
cfg.La = 4 * ones(size(cfg.Ka));
cfg.Lb = 3 * ones(size(cfg.Kb));
cfg.Lc = 3 * ones(size(cfg.Kc));
cfg.Mb = 2 * ones(size(cfg.Kb));
cfg.Mc = 2 * ones(size(cfg.Kc));
cfg.calculo = 'DOMP';
cfg.Nmax = 150;
cfg.h = [];
cfg.verbose = true;
cfg.useLastSparseSolution = true;

modelGmp = model_gmp_domp_omp(ymed, xmed, cfg);
modelPniq = model_pniq_gmp_domp_omp(ymed, xmed, cfg);

fprintf('\nGMP NMSE:       %.3f dB (%d complex coefficients)\n', ...
    modelGmp.nmse, nnz(abs(modelGmp.h) > 0));
fprintf('PN-IQ-GMP NMSE: %.3f dB (%d PN-IQ features, %d real parameters)\n', ...
    modelPniq.nmse, nnz(abs(modelPniq.h) > 0), modelPniq.realParameterCount);
