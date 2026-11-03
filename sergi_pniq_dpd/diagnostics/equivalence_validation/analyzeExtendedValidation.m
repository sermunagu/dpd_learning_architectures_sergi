function analyzeExtendedValidation(out)
% ANALYZEEXTENDEDVALIDATION Compare saved accelerated fits with original points.
% Input: existing diagnostic output directory. No training; writes analysis here.
    here = fileparts(mfilename('fullpath')); root = fileparts(fileparts(here));
    oldPath = path; cleanup = onCleanup(@() path(oldPath));
    addpath(genpath(fullfile(root, 'toolbox')));
    source = fullfile(root, 'results', 'dpd_sweep', 'tpf1484cb1_eb1d_4fe1_9d7e_13899ee8f7e5');
    previous = fullfile(fileparts(here), 'session_acceleration', 'tp705818e5_a36d_45e4_ae24_88e83faabad1');
    S = load(fullfile(source, 'experiment.mat'));
    D = load(fullfile(source, 'sweep_dense_source.mat'));
    R = load(fullfile(out, 'expected_rng.mat'));
    stats = D.denseSource.denseFit.normalization;
    [f, ~, rotation] = buildPhaseNormDataset(S.x, S.y, S.cfg.pnnn.M, S.cfg.pnnn.orders, S.cfg.pnnn.featMode, S.cfg.pnnn);
    normalized = (f.' - stats.muX) ./ stats.sigmaX; clear f D
    referenceTable = readtable(fullfile(source, 'dpd_complexity_sweep.csv'), 'TextType', 'string');
    hybrid = referenceTable; numerical = table(); layers = table(); ranks = table();
    for P = [20 70 100 290 310 400 500]
        ref = load(fullfile(source, sprintf('pnnn_target_%04d.mat', P)), 'point');
        reference = ref.point.model.network;
        if ismember(P, [20 70 290 500])
            A = load(fullfile(out, sprintf('accelerated_P%04d.mat', P)));
            net = A.result.network; masks = A.result.masks; finalRng = A.finalRng;
            seconds = A.seconds; diag = A.result.diagnostic; origin = "new";
        else
            oldBudgets = [100 310 400]; oldRuns = [6 5 4]; runNumber = oldRuns(oldBudgets == P);
            A = load(fullfile(previous, sprintf('run_%02d.mat', runNumber)));
            net = reference; net.Learnables = A.learnables; masks = A.masks;
            finalRng = A.finalRng; seconds = A.row.TotalSeconds; diag = A.d; origin = "reused";
        end
        a = []; b = []; mask = []; zeroExact = true; zeroPatternExact = true;
        for k = 1:height(net.Learnables)
            v = double(extractdata(net.Learnables.Value{k}));
            r = double(extractdata(reference.Learnables.Value{k}));
            a = [a; v(:)]; b = [b; r(:)]; mask = [mask; masks{k}(:)]; %#ok<AGROW>
            zeroExact = zeroExact && all(v(~masks{k}) == 0) && all(r(~ref.point.model.masks{k}) == 0);
            zeroPatternExact = zeroPatternExact && isequal(v == 0, r == 0);
            layerRow = table(P, string(net.Learnables.Layer(k)), string(net.Learnables.Parameter(k)), ...
                max(abs(v(:)-r(:))), norm(v(:)-r(:))/max(norm(r(:)), realmin), nnz(v~=r), ...
                'VariableNames', {'P','Layer','Parameter','MaxAbsoluteError','RelativeL2','ChangedElements'});
            layers = [layers; layerRow]; %#ok<AGROW>
        end
        pred = predictPNNN(net, normalized, stats, rotation(:)); target = ref.point.fullSignalPrediction;
        delta = double(pred(:)) - double(target(:));
        row = struct('P', P, 'Origin', origin, 'Seconds', seconds, 'Epochs', numel(diag.epochWall), ...
            'MasksExact', isequal(masks, ref.point.model.masks), 'PrunedZerosExact', zeroExact, ...
            'ZeroPatternExact', zeroPatternExact, 'ActiveParameters', nnz(mask), 'PrunedParameters', nnz(~mask), ...
            'ActiveNonzeroOriginal', nnz(b(logical(mask))), 'ActiveNonzeroAccelerated', nnz(a(logical(mask))), ...
            'RNGExact', isequal(finalRng, R.expectedRng), 'StateExact', isequal(net.State, reference.State), ...
            'WeightsExact', isequal(net.Learnables, reference.Learnables), 'ChangedParameters', nnz(a~=b), ...
            'WeightMaxAbs', max(abs(a-b)), 'WeightRelativeL2', norm(a-b)/norm(b), ...
            'PredictionMaxAbs', max(abs(delta)), 'PredictionRelativeL2', norm(delta)/norm(double(target(:))), ...
            'OriginalNMSE', nmseComplexDb(S.y, target), 'AcceleratedNMSE', nmseComplexDb(S.y, pred));
        row.NMSEDelta = row.AcceleratedNMSE - row.OriginalNMSE;
        id = S.split.identificationIndices; ev = S.split.evaluationIndices;
        row.OriginalIdentificationNMSE = nmseComplexDb(S.y(id), target(id));
        row.AcceleratedIdentificationNMSE = nmseComplexDb(S.y(id), pred(id));
        row.OriginalEvaluationNMSE = nmseComplexDb(S.y(ev), target(ev));
        row.AcceleratedEvaluationNMSE = nmseComplexDb(S.y(ev), pred(ev));
        row.EvaluationNMSEDelta = row.AcceleratedEvaluationNMSE - row.OriginalEvaluationNMSE;
        row.EvaluationPredictionRelativeL2 = norm(delta(ev))/norm(double(target(ev)));
        row.HitRate = diag.hitRate; row.Occupancy = diag.occupancy;
        row.Pass = row.PredictionRelativeL2 < 1e-5 && abs(row.NMSEDelta) < 1e-4 && ...
            row.MasksExact && row.PrunedZerosExact && row.ActiveParameters == P && row.RNGExact;
        numerical = [numerical; struct2table(row)]; %#ok<AGROW>
        j = referenceTable.Model == "PNNN" & referenceTable.ActualRealParameters == P;
        assert(nnz(j) == 1);
        assert(abs(referenceTable.EvaluationNMSEdB(j)-row.OriginalEvaluationNMSE) < 1e-10);
        hybrid.FullSignalNMSEdB(j) = row.AcceleratedNMSE;
        hybrid.EvaluationNMSEdB(j) = row.AcceleratedEvaluationNMSE;
        sameP = referenceTable.ActualRealParameters == P;
        oldFamily = referenceTable(sameP,:); newFamily = hybrid(sameP,:);
        [~, oldOrder] = sort(oldFamily.EvaluationNMSEdB); [~, newOrder] = sort(newFamily.EvaluationNMSEdB);
        ranks = [ranks; table(P, isequal(oldOrder,newOrder), min(abs(diff(sort(oldFamily.EvaluationNMSEdB)))), ...
            'VariableNames', {'P','FamilyRankingUnchanged','SmallestFamilyGapDb'})]; %#ok<AGROW>
        fprintf('P%d: relative prediction %.9g; NMSE delta %+.9g dB; PASS=%d\n', P, row.PredictionRelativeL2, row.NMSEDelta, row.Pass);
    end
    writetable(numerical, fullfile(out, 'equivalence.csv'));
    writetable(layers, fullfile(out, 'weight_details.csv'));
    writetable(ranks, fullfile(out, 'family_rankings.csv'));
    baselineInput = referenceTable; baselineInput.FullSignalNMSEdB = referenceTable.EvaluationNMSEdB;
    hybridInput = hybrid; hybridInput.FullSignalNMSEdB = hybrid.EvaluationNMSEdB;
    baselineSelection = selectionOutcome(baselineInput, S.cfg.selection);
    hybridSelection = selectionOutcome(hybridInput, S.cfg.selection);
    savedSweep = load(fullfile(source, 'dpd_complexity_sweep.mat'), 'sweep');
    assert(isequaln(savedSweep.sweep.config.selection, S.cfg.selection));
    savedSelectionReason = savedSweep.sweep.selectionReason;
    [~, oldOrder] = sort(numerical.OriginalEvaluationNMSE);
    [~, newOrder] = sort(numerical.AcceleratedEvaluationNMSE);
    pnnnRows = referenceTable.Model == "PNNN";
    [~, oldGridOrder] = sort(referenceTable.EvaluationNMSEdB(pnnnRows));
    [~, newGridOrder] = sort(hybrid.EvaluationNMSEdB(pnnnRows));
    conclusions = struct('SelectedOriginal', baselineSelection.selectedParameters, ...
        'SelectedHybrid', hybridSelection.selectedParameters, 'PNNNRankingUnchanged', isequal(oldOrder,newOrder), ...
        'HybridFullGridPNNNRankingUnchanged', isequal(oldGridOrder,newGridOrder), ...
        'FamilyRankingsUnchanged', all(ranks.FamilyRankingUnchanged), ...
        'SelectionOutcomeUnchanged', isequaln(baselineSelection.selectedParameters, hybridSelection.selectedParameters) && ...
            baselineSelection.errorId == hybridSelection.errorId, ...
        'OriginalSelectionStatus', baselineSelection.errorId, 'HybridSelectionStatus', hybridSelection.errorId, ...
        'SavedSweepHasSelection', ~isempty(savedSweep.sweep.selection));
    save(fullfile(out, 'conclusions.mat'), 'conclusions', 'baselineSelection', 'hybridSelection', 'savedSelectionReason');
    writetable(struct2table(conclusions), fullfile(out, 'conclusions.csv'));
    disp(numerical(:, {'P','Pass','WeightMaxAbs','WeightRelativeL2','PredictionRelativeL2','NMSEDelta'}));
    disp(conclusions);
    disp(savedSelectionReason);
end

function outcome = selectionOutcome(input, config)
% Preserve the production behavior when no jointly stabilized point exists.
    try
        selection = selectOperatingPoint(input, config);
        outcome = struct('selectedParameters', selection.selectedParameters, 'errorId', "", 'selection', selection);
    catch exception
        if ~strcmp(exception.identifier, 'selectOperatingPoint:NoJointlyStabilizedPoint')
            rethrow(exception);
        end
        outcome = struct('selectedParameters', NaN, 'errorId', string(exception.identifier), 'selection', []);
    end
end
