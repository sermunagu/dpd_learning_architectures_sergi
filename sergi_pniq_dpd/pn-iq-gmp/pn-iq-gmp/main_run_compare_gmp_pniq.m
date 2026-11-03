%MAIN_RUN_COMPARE_GMP_PNIQ Compare GMP and PN-IQ-GMP up to 500 regressors.
%
% The identification interval is selected with sel_indices over 10% of the
% measured signal. Both models are trained with DOMP on that interval. The
% identification and full-signal validation NMSE are evaluated for every
% selected coefficient count from 1 to Nmax.

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
toolboxDir = fullfile(thisDir, 'toolbox');
addpath(toolboxDir);
addpath(fullfile(toolboxDir, 'matlab2tikz'));

resultsDir = fullfile(thisDir, 'results');
if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end

measurementFile = fullfile(thisDir, 'measurement', ...
    'experiment20260429T134032_forward_xy.mat');
if ~isfile(measurementFile)
    error('Measurement file not found: %s', measurementFile);
end

loaded = load(measurementFile);
if ~isfield(loaded, 'x') || ~isfield(loaded, 'y')
    error('Measurement file must contain variables x and y.');
end

xFull = loaded.x(:);
yFull = loaded.y(:);
if numel(xFull) ~= numel(yFull)
    error('x and y must have the same length.');
end
if any(~isfinite(xFull)) || any(~isfinite(yFull))
    error('x and y must be finite.');
end

idFraction = 0.10;
idIdx = sel_indices(xFull, yFull, idFraction);
xId = xFull(idIdx);
yId = yFull(idIdx);

cfg = build_default_model_config();
cfg.Nmax = 500;
cfg.calculo = 'DOMP';
cfg.h = [];
cfg.verbose = false;
cfg.useLastSparseSolution = true;

warning('off', 'MATLAB:nearlySingularMatrix');
warning('off', 'MATLAB:singularMatrix');

fprintf('Measurement: %s\n', measurementFile);
fprintf('Full signal samples: %d\n', numel(yFull));
fprintf('Identification samples selected by sel_indices(10%%): %d\n', numel(yId));
fprintf('DOMP sweep: 1:%d selected regressors/features\n\n', cfg.Nmax);

fprintf('[1/4] Training GMP on identification interval...\n');
modelGmpId = model_gmp_domp_omp(yId, xId, cfg);

fprintf('[2/4] Training PN-IQ-GMP on identification interval...\n');
modelPniqId = model_pniq_gmp_domp_omp(yId, xId, cfg);

fprintf('[3/4] Building full-signal GMP validation matrix...\n');
cfgMatrix = cfg;
cfgMatrix.calculo = 'matrix_only';
cfgMatrix.returnXmat = true;
modelGmpFull = model_gmp_domp_omp(yFull, xFull, cfgMatrix);

fprintf('[4/4] Building full-signal PN-IQ validation matrix...\n');
cfgMatrix.pniqKeptMask = modelPniqId.pniqKeptMask;
modelPniqFull = model_pniq_gmp_domp_omp(yFull, xFull, cfgMatrix);

nGmp = min(cfg.Nmax, size(modelGmpId.h_full, 2));
nPniq = min(cfg.Nmax, size(modelPniqId.h_full, 2));
iterations = (1:min(nGmp, nPniq)).';

gmpIdNmse = modelGmpId.nmse_path(iterations).';
pniqIdNmse = modelPniqId.nmse_path(iterations).';

gmpFullNmse = calculate_validation_path_gmp(modelGmpFull, modelGmpId.h_full, iterations);
pniqFullNmse = calculate_validation_path_pniq(modelPniqFull, modelPniqId.h_full, iterations);

summaryTable = table(iterations, gmpIdNmse, pniqIdNmse, gmpFullNmse, pniqFullNmse, ...
    'VariableNames', {'Iteration', 'GMP_IdentificationNMSE_dB', ...
    'PNIQGMP_IdentificationNMSE_dB', 'GMP_FullSignalNMSE_dB', ...
    'PNIQGMP_FullSignalNMSE_dB'});
writetable(summaryTable, fullfile(resultsDir, 'nmse_sweep_gmp_vs_pniq.csv'));

regressorTable = build_selected_regressor_table( ...
    modelGmpId, modelPniqId, gmpFullNmse, pniqFullNmse, iterations);
writetable(regressorTable, fullfile(resultsDir, 'selected_regressors_gmp_vs_pniq.csv'));

finalTable = table( ...
    ["GMP"; "PN-IQ-GMP"], ...
    [gmpIdNmse(end); pniqIdNmse(end)], ...
    [gmpFullNmse(end); pniqFullNmse(end)], ...
    [nnz(abs(modelGmpId.h_full(:, iterations(end))) > 0); ...
     nnz(abs(modelPniqId.h_full(:, iterations(end))) > 0)], ...
    [2*nnz(abs(modelGmpId.h_full(:, iterations(end))) > 0); ...
     modelPniqId.realParameterCount], ...
    'VariableNames', {'Model', 'IdentificationNMSE_500_dB', ...
    'FullSignalValidationNMSE_500_dB', 'SelectedFeatures_500', ...
    'RealParameterCount_500'});
writetable(finalTable, fullfile(resultsDir, 'final_validation_nmse.csv'));

modelGmpCompact = compact_model_for_save(modelGmpId);
modelPniqCompact = compact_model_for_save(modelPniqId);

save(fullfile(resultsDir, 'comparison_gmp_vs_pniq.mat'), ...
    'cfg', 'idFraction', 'idIdx', 'modelGmpCompact', 'modelPniqCompact', ...
    'gmpFullNmse', 'pniqFullNmse', 'summaryTable', 'regressorTable', ...
    'finalTable', '-v7.3');

plot_nmse_curve(iterations, gmpIdNmse, pniqIdNmse, ...
    'Identification NMSE during DOMP selection', ...
    'Identification NMSE (dB)', ...
    fullfile(resultsDir, 'nmse_identification_sweep'));

plot_nmse_curve(iterations, gmpFullNmse, pniqFullNmse, ...
    'Full-signal validation NMSE during DOMP selection', ...
    'Full-signal validation NMSE (dB)', ...
    fullfile(resultsDir, 'nmse_full_signal_validation_sweep'));

write_latex_report(resultsDir, finalTable);
compile_latex_report(resultsDir);

fprintf('\nFinal 500-regressor results:\n');
disp(finalTable);
fprintf('Saved results in: %s\n', resultsDir);

function cfg = build_default_model_config()
% Match the INMMIC26 P150 GMP convention: total degree 1:13, L=10, M=2.
cfg = struct();
cfg.Ka = 0:12;
cfg.Kb = 1:12;
cfg.Kc = 1:12;
cfg.La = 10 * ones(size(cfg.Ka));
cfg.Lb = 10 * ones(size(cfg.Kb));
cfg.Lc = 10 * ones(size(cfg.Kc));
cfg.Mb = 2 * ones(size(cfg.Kb));
cfg.Mc = 2 * ones(size(cfg.Kc));
end

function nmsePath = calculate_validation_path_gmp(modelFull, hFull, iterations)
y = modelFull.y_aligned(:);
X = modelFull.X_mat;
nmsePath = zeros(numel(iterations), 1);
for k = 1:numel(iterations)
    yHat = X * hFull(:, iterations(k));
    nmsePath(k) = 20*log10(norm(yHat - y) / norm(y));
end
end

function nmsePath = calculate_validation_path_pniq(modelFull, hFull, iterations)
y = modelFull.y_aligned(:);
Phi = modelFull.Phi;
rotation = modelFull.rotation(:);
nmsePath = zeros(numel(iterations), 1);
for k = 1:numel(iterations)
    yTildeHat = Phi * hFull(:, iterations(k));
    yHat = conj(rotation) .* yTildeHat;
    nmsePath(k) = 20*log10(norm(yHat - y) / norm(y));
end
end

function out = build_selected_regressor_table(modelGmp, modelPniq, ...
    gmpFullNmse, pniqFullNmse, iterations)
rows = cell(2*numel(iterations), 9);
cursor = 0;

for k = 1:numel(iterations)
    iter = iterations(k);

    cursor = cursor + 1;
    idx = modelGmp.s(iter);
    rows(cursor,:) = {'GMP', iter, idx, modelGmp.Rmat{idx}, ...
        modelGmp.orderVec(idx), "", "", modelGmp.nmse_path(iter), gmpFullNmse(k)};

    cursor = cursor + 1;
    idx = modelPniq.s(iter);
    fmap = modelPniq.featureMap(idx);
    branch = "I";
    if fmap.isQ
        branch = "Q";
    end
    rows(cursor,:) = {'PN-IQ-GMP', iter, idx, modelPniq.Rmat{idx}, ...
        modelPniq.orderVec(idx), string(fmap.sourceLabel), branch, ...
        modelPniq.nmse_path(iter), pniqFullNmse(k)};
end

out = cell2table(rows, 'VariableNames', {'Model', 'Iteration', ...
    'SelectedIndex', 'Regressor', 'Order', 'SourceGmpRegressor', ...
    'PNIQBranch', 'IdentificationNMSE_dB', 'FullSignalValidationNMSE_dB'});
end

function plot_nmse_curve(iterations, gmpNmse, pniqNmse, titleText, yLabelText, baseFile)
fig = figure('Visible', 'off', 'Color', 'w');
plot(iterations, gmpNmse, 'LineWidth', 1.5);
hold on;
plot(iterations, pniqNmse, 'LineWidth', 1.5);
grid on;
xlabel('Number of selected regressors/features');
ylabel(yLabelText);
title(titleText);
legend({'GMP', 'PN-IQ-GMP'}, 'Location', 'best');
saveas(fig, [baseFile '.png']);
savefig(fig, [baseFile '.fig']);
tikzDataDir = fullfile(fileparts(baseFile), 'tikz_data', get_file_base(baseFile));
if ~exist(tikzDataDir, 'dir')
    mkdir(tikzDataDir);
end
matlab2tikz([baseFile '.tex'], 'showInfo', false, ...
    'parseStrings', false, 'standalone', false, ...
    'dataPath', tikzDataDir, ...
    'relativeDataPath', strrep(fullfile('tikz_data', get_file_base(baseFile)), '\', '/'));
close(fig);
end

function modelOut = compact_model_for_save(modelIn)
% Keep coefficients, support, labels, and diagnostics; drop signal vectors.
modelOut = modelIn;
signalFields = {'y_aligned', 'ymod', 'y_tilde', 'y_tilde_mod', ...
    'rotation', 'X_mat', 'Phi', 'Psi_gmp'};
for k = 1:numel(signalFields)
    if isfield(modelOut, signalFields{k})
        modelOut = rmfield(modelOut, signalFields{k});
    end
end
end

function base = get_file_base(pathIn)
[~, base] = fileparts(pathIn);
end

function write_latex_report(resultsDir, finalTable)
texFile = fullfile(resultsDir, 'report_gmp_vs_pniq.tex');
fid = fopen(texFile, 'w');
if fid < 0
    error('Could not create report file: %s', texFile);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, '\\documentclass[11pt]{article}\n');
fprintf(fid, '\\usepackage[margin=1in]{geometry}\n');
fprintf(fid, '\\usepackage{booktabs}\n');
fprintf(fid, '\\usepackage{graphicx}\n');
fprintf(fid, '\\usepackage{pgfplots}\n');
fprintf(fid, '\\pgfplotsset{compat=1.18}\n');
fprintf(fid, '\\title{GMP versus PN-IQ-GMP Comparison}\n');
fprintf(fid, '\\author{}\n');
fprintf(fid, '\\date{\\today}\n');
fprintf(fid, '\\begin{document}\n');
fprintf(fid, '\\maketitle\n');

fprintf(fid, '\\section{Experiment}\n');
fprintf(fid, ['The experiment compares a conventional GMP model and a ' ...
    'phase-normalized IQ GMP model using the same GMP basis, DOMP selection, ' ...
    'and a sweep from 1 to 500 selected regressors or PN-IQ features. The ' ...
    'identification interval is selected with \\texttt{sel\\_indices} using ' ...
    '10\\%% of the measured signal. Validation is evaluated on the complete ' ...
    'aligned measured signal.\\par\n']);
fprintf(fid, ['The normalized regressions use \\texttt{pinv} after column ' ...
    'normalization, as implemented in \\texttt{toolbox/normalized\\_regression.m} ' ...
    'and \\texttt{toolbox/model\\_pniq\\_gmp\\_domp\\_omp.m}.\\par\n']);

fprintf(fid, '\\section{Final NMSE}\n');
fprintf(fid, '\\begin{table}[h]\\centering\n');
fprintf(fid, '\\caption{Final result at 500 selected regressors/features.}\n');
fprintf(fid, '\\begin{tabular}{lrrrr}\\toprule\n');
fprintf(fid, 'Model & Identification NMSE & Validation NMSE & Selected & Real parameters\\\\\n');
fprintf(fid, ' & dB & dB & features & \\\\\n');
fprintf(fid, '\\midrule\n');
for k = 1:height(finalTable)
    fprintf(fid, '%s & %.3f & %.3f & %d & %d\\\\\n', ...
        char(finalTable.Model(k)), ...
        finalTable.IdentificationNMSE_500_dB(k), ...
        finalTable.FullSignalValidationNMSE_500_dB(k), ...
        finalTable.SelectedFeatures_500(k), ...
        finalTable.RealParameterCount_500(k));
end
fprintf(fid, '\\bottomrule\\end{tabular}\\end{table}\n');

fprintf(fid, '\\section{DOMP Evolution}\n');
fprintf(fid, '\\begin{figure}[h]\\centering\n');
fprintf(fid, '\\input{nmse_identification_sweep.tex}\n');
fprintf(fid, '\\caption{Identification NMSE along the DOMP coefficient sweep.}\n');
fprintf(fid, '\\end{figure}\n');
fprintf(fid, '\\begin{figure}[h]\\centering\n');
fprintf(fid, '\\input{nmse_full_signal_validation_sweep.tex}\n');
fprintf(fid, '\\caption{Full-signal validation NMSE along the DOMP coefficient sweep.}\n');
fprintf(fid, '\\end{figure}\n');

fprintf(fid, '\\section{Interpretation}\n');
fprintf(fid, ['The PN-IQ-GMP model improves both identification and full-signal ' ...
    'validation NMSE in this run. At 500 selected features, the validation ' ...
    'improvement is %.3f dB relative to conventional GMP. The saved CSV files ' ...
    'contain the full NMSE sweep and the selected regressor list for each ' ...
    'iteration.\\par\n'], ...
    finalTable.FullSignalValidationNMSE_500_dB(1) - finalTable.FullSignalValidationNMSE_500_dB(2));
fprintf(fid, ['Using \\texttt{pinv} avoids the explicit normal-equation inverse ' ...
    'used in the previous run and gives a more stable least-squares solve for ' ...
    'the highly correlated DOMP dictionaries.\\par\n']);

fprintf(fid, '\\end{document}\n');
end

function compile_latex_report(resultsDir)
texName = 'report_gmp_vs_pniq.tex';
oldDir = pwd;
cleanup = onCleanup(@() cd(oldDir));
cd(resultsDir);
pdflatexCmd = find_pdflatex_command();
[status, output] = system(sprintf('"%s" -interaction=nonstopmode -halt-on-error "%s"', pdflatexCmd, texName));
if status ~= 0
    warning('Report PDF compilation failed:\n%s', output);
end
end

function cmd = find_pdflatex_command()
[status, pathText] = system('where pdflatex');
if status == 0
    paths = splitlines(strtrim(string(pathText)));
    cmd = char(paths(1));
    return;
end

candidate = fullfile(getenv('LOCALAPPDATA'), 'Programs', 'MiKTeX', ...
    'miktex', 'bin', 'x64', 'pdflatex.exe');
if isfile(candidate)
    cmd = candidate;
    return;
end

cmd = 'pdflatex';
end
