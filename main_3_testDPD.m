% Validate capsule_v3_DPD signals grouped by comparison type.
%
% Run after main_1_learnDPD and main_2_testexperiment
% in the MATLAB session that owns the connected TRx object.
%
% Optional group filter:
%   dpd_comparison_type = 'bayes_Nob';
%   dpd_comparison_type = 'baselines_seq';
%   dpd_comparison_type = 'baselines_par';
% Optional original signal indices (before the support-size filter):
%   dpd_indices = 88:90;
% Optional support-size filter:
%   dpd_n_regressors = 100;

projectRoot = fileparts(mfilename('fullpath'));
cd(projectRoot);
addpath(fullfile(projectRoot, 'toolbox'));
addpath(fullfile(projectRoot, 'toolbox_ADRV'));
addpath(fullfile(projectRoot, 'toolbox_signalgen'));
addpath(fullfile(projectRoot, 'confset'));

if ~exist('filenamedate', 'var') || isempty(filenamedate)
    error('DPD:MissingExperiment', ...
        'Run main_1 and main_2 first, or set filenamedate to a completed ILC experiment.');
end
filenamedate = char(string(filenamedate));
requiredSessionVars = {'fs', 'info_signal', 'usw', 'fc', 'Lout'};
for requiredIdx = 1:numel(requiredSessionVars)
    if ~exist(requiredSessionVars{requiredIdx}, 'var')
        error('DPD:MissingSessionState', ...
            'Missing %s. Run this script in the MATLAB session used for main_1.', ...
            requiredSessionVars{requiredIdx});
    end
end

% Preserve the TRx object that already exists in the open MATLAB session,
% then expose that same handle through the global used by measureADRV.
% Deliberately do not reconnect or create another ADRV object here.
if ~evalin('base', 'exist(''TRx'', ''var'')')
    error('ADRV:MissingTRx', ...
        ['TRx is not available in this MATLAB session. Launch this test ' ...
        'from the session that owns the connected ADRV object.']);
end
sessionTRx = evalin('base', 'TRx');
global TRx
TRx = sessionTRx;
clear sessionTRx;
trxInfo = validate_adrv_trx(TRx);
fprintf('Using existing TRx: class=%s, connected=%d, TX mask=%g, RX mask=%g\n', ...
    trxInfo.class, trxInfo.isConnected, trxInfo.txChannels, trxInfo.rxChannels);

inline_functions

experimentPath = fullfile('results', ['experiment' filenamedate]);
loadedExperiment = load(experimentPath, 'meas_out', 'exp_config');
exp_config = loadedExperiment.exp_config;
% Last measurement with DPD (main_1 may append a final one without DPD;
% older experiments do not have the measureWithoutDPDAtEnd field)
iLastDPD = numel(loadedExperiment.meas_out);
if isfield(exp_config, 'measureWithoutDPDAtEnd') && exp_config.measureWithoutDPDAtEnd
    iLastDPD = iLastDPD - 1;
end
base_meas_out = [loadedExperiment.meas_out(1) loadedExperiment.meas_out(iLastDPD)];
u = base_meas_out(1).u;

executionPattern = fullfile('results', ...
    ['experiment' filenamedate '_xy_execution_*.mat']);
executionFiles = dir(executionPattern);

if exist('dpd_comparison_type', 'var') && ~isempty(dpd_comparison_type)
    requestedType = char(string(dpd_comparison_type));
    comparisonTypes = strings(size(executionFiles));
    for ii = 1:numel(executionFiles)
        comparisonTypes(ii) = string(execution_comparison_type( ...
            executionFiles(ii).name, filenamedate));
    end
    exactMatches = strcmpi(comparisonTypes, requestedType);
    if any(exactMatches)
        keep = exactMatches;
    else
        keep = startsWith(comparisonTypes, [requestedType '_'], ...
            'IgnoreCase', true);
    end
    executionFiles = executionFiles(keep);
end

if isempty(executionFiles)
    legacyPath = fullfile('results', ...
        ['experiment' filenamedate '_xy_execution.mat']);
    if exist(legacyPath, 'file')
        warning('No split execution files found. Loading legacy monolithic file: %s', legacyPath);
        executionFiles = dir(legacyPath);
    else
        error('No DPD execution files found for experiment %s.', filenamedate);
    end
end

dBm = @(x) 10*log10(rms(x).^2/100)+30;

% Safety limits can be overridden before launching this script.
if ~exist('dpd_safety_average_margin_dB', 'var')
    dpd_safety_average_margin_dB = 0.5;
end
if ~exist('dpd_safety_peak_margin_dB', 'var')
    dpd_safety_peak_margin_dB = 1.25;
end
if ~exist('dpd_safety_cfr_papr_limit_dB', 'var')
    dpd_safety_cfr_papr_limit_dB = 15;
end
if isfield(base_meas_out(end), 'xCFR') && ~isempty(base_meas_out(end).xCFR)
    safetyReferenceSignal = base_meas_out(end).xCFR;
else
    safetyReferenceSignal = base_meas_out(end).x;
end

for fileIdx = 1:numel(executionFiles)
    executionPath = fullfile(executionFiles(fileIdx).folder, executionFiles(fileIdx).name);
    clear dpd % Release any previous large export before loading the next group.
    executionData = load(executionPath, 'dpd', 'comparison_type');
    dpd = executionData.dpd;
    executionData = rmfield(executionData,'dpd');
    selected_indices = 1:numel(dpd);
    indexTag = '';
    if exist('dpd_indices','var') && ~isempty(dpd_indices)
        [dpd, selected_indices, indexTag] = select_dpd_indices(dpd,dpd_indices);
    end
    if isfield(executionData, 'comparison_type')
        comparisonType = char(executionData.comparison_type);
    else
        comparisonType = execution_comparison_type(executionFiles(fileIdx).name, filenamedate);
    end

    runType = comparisonType;
    if exist('dpd_n_regressors', 'var') && ~isempty(dpd_n_regressors)
        if ~isfield(dpd, 'n_regressors')
            error('The DPD file %s has no n_regressors field.', executionPath);
        end
        requestedSupports = reshape(dpd_n_regressors, 1, []);
        availableSupports = [dpd.n_regressors];
        missingSupports = setdiff(requestedSupports, availableSupports);
        if ~isempty(missingSupports)
            error('%s does not contain support sizes: %s.', ...
                comparisonType, mat2str(missingSupports));
        end
        supportMask = ismember(availableSupports, requestedSupports);
        dpd = dpd(supportMask);
        selected_indices = selected_indices(supportMask);
        if isempty(dpd)
            error('%s has no signals for support sizes %s.', ...
                comparisonType, mat2str(requestedSupports));
        end
        supportTag = strjoin(string(requestedSupports), '-');
        runType = sprintf('%s_n%s', comparisonType, supportTag);
    end

    if ~isempty(indexTag)
        runType = sprintf('%s_idx%s',runType,indexTag);
    end

    fprintf('\n=== Validating %s (%d signals) ===\n', runType, numel(dpd));
    meas_out = base_meas_out;

    [safetyTable, safetyLimits] = check_dpd_signal_safety( ...
        dpd, safetyReferenceSignal, dpd_safety_cfr_papr_limit_dB, ...
        dpd_safety_average_margin_dB, dpd_safety_peak_margin_dB);
    safetyPath = fullfile('results', ...
        ['experiment' filenamedate '_DPD_safety_' runType '.csv']);
    writetable(safetyTable, safetyPath);

    fprintf(['Safety reference: average %.3f dBm, PAPR %.3f dB, ' ...
        'peak %.3f dBm.\n'], safetyLimits.referenceAveragePower_dBm, ...
        safetyLimits.referencePapr_dB, safetyLimits.referencePeakPower_dBm);
    fprintf(['Safety limits: average <= %.3f dBm, PAPR <= %.3f dB, ' ...
        'peak <= %.3f dBm.\n'], safetyLimits.maxAveragePower_dBm, ...
        safetyLimits.maxPapr_dB, safetyLimits.maxPeakPower_dBm);

    if any(~safetyTable.safe)
        unsafeSignals = safetyTable(~safetyTable.safe, :);
        disp(unsafeSignals);
        error(['DPD safety preflight failed for %s: %d/%d signals are unsafe. ' ...
            'Nothing from this comparison was transmitted. Report: %s'], ...
            runType, height(unsafeSignals), height(safetyTable), safetyPath);
    end
    fprintf('Safety preflight passed for all %d signals. Report: %s\n', ...
        height(safetyTable), safetyPath);

    for k = 1:numel(dpd)
        fprintf('Signal %d/%d: %s\n', k, numel(dpd), dpd(k).modeltype);
        x = dpd(k).yvalmod;
        xCFR = CFR_hard(x, dpd_safety_cfr_papr_limit_dB);

        [y, measdata] = measureADRV(xCFR, exp_config.captureTime);
        y = full_sync_5G(y, xCFR, fs, info_signal.BW, info_signal.Foff);
        y = y*10^(Lout/20); y = y(:); y = y-mean(y);

        try
            [~, ~, EVM, NMSE] = analiza_medidas_5GNR_v6( ...
                usw, u, y, info_signal, fc);
        catch postprocessError
            failedCapturePath = fullfile('results', sprintf( ...
                'experiment%s_DPD_failed_capture_%s_signal_%03d.mat', ...
                filenamedate, runType, k));
            failed_dpd = dpd(k); %#ok<NASGU>
            save(failedCapturePath, 'x', 'xCFR', 'y', 'measdata', ...
                'failed_dpd', 'info_signal', 'exp_config', '-v7.3');
            fprintf(2, 'Post-processing failed; capture preserved at: %s\n', ...
                failedCapturePath);
            rethrow(postprocessError);
        end
        [ACPR, NMSE] = ACPROFDM(u, y, fs, ...
            info_signal.BW, info_signal.BWeff, info_signal.Foff);

        [G, Gc, Phc] = calculate_Gc(y, xCFR);
        gc = 10^(Gc/20);
        g = 10^(G/20);
        G0 = 65;
        g0 = 10^(G0/20);

        meas.descr = dpd(k).modeltype;
        meas.mu = [];
        store_data_and_show_performance
        update_figures
    end

    outputPath = fullfile('results', ...
        ['experiment' filenamedate '_DPD_' runType '.mat']);
    save(outputPath, 'meas_out', 'comparisonType', 'runType', 'selected_indices', '-v7.3');
    fprintf('Saved validation result: %s\n', outputPath);

    clear dpd executionData meas_out;
end

function comparisonType = execution_comparison_type(fileName, filenamedate)
    prefix = ['experiment' filenamedate '_xy_execution_'];
    [~, baseName] = fileparts(fileName);
    if startsWith(baseName, prefix)
        comparisonType = extractAfter(baseName, strlength(prefix));
        comparisonType = char(comparisonType);
    else
        comparisonType = 'legacy';
    end
end
