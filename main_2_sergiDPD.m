% Train/reuse research DPD models and export signals for main_3_testDPD.
% Optional inputs: dpd_mode, dpd_single_P, dpd_parameter_grid,
% dpd_rf_parameters, dpd_sweep_directory, dpd_export_mode. See docs/README_INTEGRACION.md.
if ~exist('filenamedate', 'var') || isempty(filenamedate)
    error('DPD:MissingExperiment', 'Set filenamedate or run main_1_learnDPD first.');
end
if ~exist('dpd_export_mode', 'var'), dpd_export_mode = 'per_budget'; end
if ~exist('dpd_mode', 'var'), dpd_mode = 'single'; end
if ~exist('dpd_single_P', 'var'), dpd_single_P = 310; end
if ~exist('dpd_parameter_grid', 'var'), dpd_parameter_grid = []; end
if ~exist('dpd_rf_parameters', 'var'), dpd_rf_parameters = []; end
if ~exist('dpd_sweep_directory', 'var'), dpd_sweep_directory = ''; end
filenamedate = char(string(filenamedate));
clear dpd % Release a previous large export before constructing another one.
[modelFile, dpd, comparison_type, executionPath, dpd_exports, dpd_sweep_result_directory] = exportSergiDPD( ...
    fileparts(mfilename('fullpath')), filenamedate, dpd_mode, dpd_single_P, ...
    dpd_parameter_grid, dpd_rf_parameters, dpd_sweep_directory, dpd_export_mode);

function [modelFile, dpd, comparison_type, executionPath, exports, directory] = exportSergiDPD(root, stamp, mode, singleP, grid, rf, directory, exportMode)
% Train or reuse bundles, then export unchanged inference and traceability.
% Inputs: root, capture timestamp, mode, budgets and optional saved sweep.
% Outputs: last export values, all export paths and the sweep directory.
    mode = validatestring(mode, {'single','sweep'});
    exportMode = validatestring(exportMode, {'per_budget','combined'});
    combined = strcmp(mode,'sweep') && strcmp(exportMode,'combined');
    assert(isrow(stamp) && ~isempty(regexp(stamp, '^\d{8}T\d{6}$', 'once')), ...
        'DPD:InvalidTimestamp', 'Use a timestamp in yyyymmddTHHMMSS format.');
    captureFile = fullfile(root,'results',['experiment' stamp '_xy.mat']);
    experimentFile = fullfile(root,'results',['experiment' stamp '.mat']);
    if ~isfile(captureFile) || ~isfile(experimentFile)
        error('DPD:MissingCapture', 'Both experiment and _xy files are required for %s.', stamp);
    end
    capture = load(captureFile);
    validateattributes(capture.x, {'double','single'}, {'vector','nonempty','finite'});
    validateattributes(capture.y, {'double','single'}, {'vector','nonempty','finite','numel',numel(capture.x)});
    originalPath = path;
    pathCleanup = onCleanup(@() path(originalPath));
    research = fullfile(root,'sergi_pniq_dpd');
    addpath(fullfile(research,'DPD'),fullfile(research,'config'),genpath(fullfile(research,'toolbox')));
    reuse = strcmp(mode,'sweep') && strlength(string(directory)) > 0;
    if strcmp(mode,'single')
        validateattributes(singleP, {'numeric'}, {'scalar'});
        grid = singleP;
        rf = singleP;
        directory = '';
    elseif reuse
        directory = char(java.io.File(char(directory)).getCanonicalPath());
        state = load(fullfile(directory,'experiment.mat'),'cfg','x','y','provenance');
        checkSweepCapture(state,capture);
        savedGrid = state.cfg.sweep.parameterGrid;
        if isempty(grid), grid = savedGrid; end
        assert(isequal(unique(double(grid(:).')),double(savedGrid(:).')), ...
            'DPD:GridMismatch', 'The requested training grid must match the saved sweep.');
    elseif isempty(grid)
        grid = 20:10:500;
    end
    grid = validateBudgets(grid);
    if combined || isempty(rf), rf = grid; end
    rf = validateBudgets(rf);
    assert(all(ismember(rf,grid)), 'DPD:InvalidSubset', 'RF budgets must belong to the training grid.');
    if combined
        exports = string(fullfile(root,'results',['experiment' stamp '_xy_execution_sergi_sweep.mat']));
        if isfile(exports)
            if ~reuse
                error('DPD:WouldOverwrite','Execution file already exists: %s',exports);
            end
            old = load(exports,'export_info');
            expected = combinedProvenance(rf,directory,captureFile);
            assert(isfield(old,'export_info') && isequal(old.export_info,expected), ...
                'DPD:WouldOverwrite','Combined export has different or missing provenance.');
            clear old
        end
    else
        exports = strings(numel(rf),1);
        for i = 1:numel(rf)
            if strcmp(mode,'single'), group = sprintf('sergi_p%d',rf(i));
            else, group = sprintf('sergi_sweep_p%04d',rf(i)); end
            exports(i) = fullfile(root,'results',['experiment' stamp '_xy_execution_' group '.mat']);
            if isfile(exports(i))
                if ~reuse
                    error('DPD:WouldOverwrite', 'Execution file already exists: %s', exports(i));
                end
                old = load(exports(i),'export_info');
                checkpoint = fullfile(directory,sprintf('models_P%04d.mat',rf(i)));
                assert(isfield(old,'export_info') && isequal(old.export_info, ...
                    struct('P',rf(i),'checkpoint',checkpoint,'captureFile',captureFile)), ...
                    'DPD:WouldOverwrite', 'Existing export has different or missing provenance: %s', exports(i));
            end
        end
    end
    if strcmp(mode,'single')
        [modelFile, ~] = trainDPD(captureFile, singleP);
        modelFiles = string(modelFile);
    else
        if reuse
            modelFiles = fullfile(directory,compose('models_P%04d.mat',rf));
            if any(~isfile(modelFiles))
                sweep = runDPDSweep(directory);
            else
                sweep = [];
            end
        else
            sweep = runDPDSweep(captureFile,grid);
            directory = char(sweep.resultDirectory);
            state = load(fullfile(directory,'experiment.mat'),'cfg','x','y','provenance');
        end
        if ~isempty(sweep)
            [present,indices] = ismember(rf,sweep.config.sweep.parameterGrid);
            assert(all(present),'Requested budgets are missing from the sweep.');
            modelFiles = sweep.modelFiles(indices);
        end
        fprintf('Reuse this sweep with dpd_sweep_directory = ''%s'';\n',directory);
    end
    if combined
        executionPath = char(exports);
        existingCombined = isfile(executionPath);
        if existingCombined
            assert(reuse,'DPD:WouldOverwrite','Combined file appeared during training.');
            old = load(executionPath,'dpd','comparison_type','index_map');
            assert(strcmp(old.comparison_type,'sergi_sweep') && numel(old.dpd)==3*numel(rf), ...
                'DPD:WouldOverwrite','Invalid existing combined export.');
            combinedDPD = old.dpd;
            oldMap = old.index_map;
            clear old
        else
            combinedDPD = repmat(struct('yvalmod',[],'modeltype',''),1,3*numel(rf));
        end
    end
    for i = 1:numel(rf)
        P = rf(i);
        modelFile = char(modelFiles(i));
        saved = load(modelFile,'bundle');
        bundle = saved.bundle;
        assert(isscalar(bundle.P) && bundle.P == P && numel(bundle.models) == 3 && ...
            height(bundle.metrics) == 3 && all(bundle.metrics.ActualRealParameters == P), ...
            'DPD:BudgetMismatch', 'Checkpoint does not contain three models at P%d.',P);
        if strcmp(mode,'sweep')
            assert(isequal(bundle.provenance,state.provenance) && ...
                strcmp(bundle.sourceFile,state.provenance.sourceFile), ...
                'DPD:CaptureMismatch', 'Bundle provenance differs from the saved sweep.');
        else
            assert(strcmp(bundle.sourceFile,captureFile),'DPD:CaptureMismatch','Wrong bundle capture.');
        end
        if isfield(capture,'fs')
            assert(isfield(bundle,'fs') && isequal(bundle.fs,capture.fs), ...
                'DPD:CaptureMismatch','Checkpoint sample rate differs from the capture.');
        end
        dpd = applyDPDModels(bundle,capture.x(:));
        labels = cellstr(["Complex_GMP_DOMP_P","PN_IQ_GMP_P","PNNN_P"] + P);
        assert(numel(dpd) == 3 && isequal({dpd.modeltype},labels),'Unexpected DPD labels or order.');
        for k = 1:3
            validateattributes(dpd(k).yvalmod, {'double','single'}, ...
                {'column','finite','numel',numel(capture.x)});
        end
        if combined
            rows = 3*i-2:3*i;
            if existingCombined
                assert(isequal(combinedDPD(rows),dpd),'DPD:WouldOverwrite','Combined signals differ at P%d.',P);
            else
                combinedDPD(rows) = dpd;
            end
            continue
        end
        executionPath = char(exports(i));
        [~,base] = fileparts(executionPath);
        comparison_type = extractAfter(base,['experiment' stamp '_xy_execution_']);
        export_info = struct('P',P,'checkpoint',modelFile,'captureFile',captureFile);
        if isfile(executionPath)
            old = load(executionPath);
            assert(reuse && isfield(old,'export_info') && isequal(old.export_info,export_info) && ...
                isequal(old.dpd,dpd) && isequal(old.comparison_type,comparison_type), ...
                'DPD:WouldOverwrite','Existing export differs: %s',executionPath);
            fprintf('Verified existing export: %s\n',executionPath);
            continue
        end
        % Publish only a complete MAT file; never replace an existing export.
        staging = [tempname(fileparts(executionPath)) '.mat'];
        stagingCleanup = onCleanup(@() deleteStaging(staging));
        save(staging,'dpd','comparison_type','export_info','-v7.3');
        assert(~isfile(executionPath),'DPD:WouldOverwrite','Execution file appeared during export.');
        [ok,message] = movefile(staging,executionPath);
        assert(ok,'DPD:ExportFailed','%s',message);
        clear stagingCleanup
        fprintf('Ready for main_3_testDPD: %s\n',executionPath);
    end
    if combined
        dpd = combinedDPD;
        clear combinedDPD
        comparison_type = 'sergi_sweep';
        export_info = combinedProvenance(rf,directory,captureFile);
        index_map = table((1:numel(dpd)).',repelem(rf(:),3),string({dpd.modeltype}).', ...
            repelem(export_info.checkpoints,3), ...
            'VariableNames',{'Index','P','ModelType','Checkpoint'});
        if existingCombined
            assert(isequal(oldMap,index_map),'DPD:WouldOverwrite','Combined index map differs.');
            fprintf('Verified existing combined export: %s\n',executionPath);
            return
        end
        staging = [tempname(fileparts(executionPath)) '.mat'];
        stagingCleanup = onCleanup(@() deleteStaging(staging));
        save(staging,'dpd','comparison_type','export_info','index_map','-v7.3');
        assert(~isfile(executionPath),'DPD:WouldOverwrite','Execution file appeared during export.');
        [ok,message] = movefile(staging,executionPath);
        assert(ok,'DPD:ExportFailed','%s',message);
        clear stagingCleanup
        fprintf('Ready for main_3_testDPD: %s (%d signals)\n',executionPath,numel(dpd));
    end
end

function info = combinedProvenance(grid,directory,captureFile)
% Return capture and checkpoint provenance for all budgets in a combined file.
    info = struct();
    info.parameterGrid = grid;
    info.checkpoints = string(fullfile(directory,compose('models_P%04d.mat',grid(:))));
    info.captureFile = captureFile;
end

function budgets = validateBudgets(budgets)
% Validate supported real-parameter budgets; return a sorted unique row.
    validateattributes(budgets, {'numeric'}, {'vector','nonempty','real','finite','integer','>=',20,'<=',500});
    assert(all(mod(budgets,2)==0),'DPD:InvalidBudget','Budgets must be even (two real parameters per linear feature).');
    budgets = unique(double(budgets(:).'));
end

function checkSweepCapture(state,capture)
% Compare saved training arrays and original DC means to the selected capture.
    x = double(capture.x(:)); y = double(capture.y(:));
    assert(isequal(mean(x),state.provenance.inputMean) && isequal(mean(y),state.provenance.outputMean), ...
        'DPD:CaptureMismatch','Capture DC means differ from the saved sweep.');
    if state.cfg.pnnn.removeDC, x = x-mean(x); y = y-mean(y); end
    assert(isequal(x,state.x) && isequal(y,state.y), ...
        'DPD:CaptureMismatch','Capture samples differ from the saved sweep.');
    assert(isfield(capture,'fs') == isfield(state.provenance,'fs'), ...
        'DPD:CaptureMismatch','Capture sample-rate metadata differs.');
    if isfield(capture,'fs')
        assert(isequal(capture.fs,state.provenance.fs),'DPD:CaptureMismatch','Capture sample rates differ.');
    end
end

function deleteStaging(filename)
% Remove an incomplete temporary export after a failed save or publication.
    if isfile(filename), delete(filename); end
end

