function runExtendedValidation()
% RUNEXTENDEDVALIDATION Fit four additional accelerated diagnostic models.
% No inputs. Writes a unique directory here; reads scientific checkpoints only.
    here = fileparts(mfilename('fullpath'));
    root = fileparts(fileparts(here));
    oldPath = path; cleanup = onCleanup(@() path(oldPath));
    addpath(here, fullfile(fileparts(here), 'session_acceleration'), genpath(fullfile(root, 'toolbox')));
    source = fullfile(root, 'results', 'dpd_sweep', 'tpf1484cb1_eb1d_4fe1_9d7e_13899ee8f7e5');
    out = tempname(here); mkdir(out);
    diary(fullfile(out, 'validation.log')); diaryCleanup = onCleanup(@() diary('off'));
    fprintf('OUTPUT: %s\n', out);
    S = load(fullfile(source, 'experiment.mat'));
    D = load(fullfile(source, 'sweep_dense_source.mat'));
    dense = D.denseSource;
    dense.runtimeConfig.training.verbose = S.cfg.training.verbose;
    assert(dense.fineTuneEpochs == 164);
    [f, t, ~] = buildPhaseNormDataset(S.x, S.y, S.cfg.pnnn.M, S.cfg.pnnn.orders, S.cfg.pnnn.featMode, S.cfg.pnnn);
    features = f.'; targets = t.'; clear f t
    options = struct('Mode', "fixed-epochs", 'TrainingRows', S.split.identificationIndices, ...
        'ValidationRows', [], 'NNSeed', S.cfg.pnnn.nnSeed, 'FineTuneEpochs', dense.fineTuneEpochs, ...
        'Config', dense.runtimeConfig, 'UseAcceleration', true);
    environment = struct('version', version, 'computer', computer, 'threads', maxNumCompThreads, ...
        'source', source, 'options', options, 'started', char(datetime('now')));
    save(fullfile(out, 'environment.mat'), 'environment');
    % Only randperm consumes RNG in the fixed-epoch fine-tuning loop.
    rng(double(options.NNSeed) + double(options.Config.pruning.fineTuneSeedOffset), 'twister');
    for epoch = 1:options.FineTuneEpochs
        randperm(numel(options.TrainingRows));
    end
    expectedRng = rng;
    previous = fullfile(fileparts(here), 'session_acceleration', 'tp705818e5_a36d_45e4_ae24_88e83faabad1');
    original = load(fullfile(previous, 'run_12.mat'), 'finalRng');
    assert(isequal(expectedRng, original.finalRng), 'RNG replay differs from saved original control.');
    save(fullfile(out, 'expected_rng.mat'), 'expectedRng');
    for P = [20 70 290 500]
        options.TargetActiveParameters = P;
        fprintf('START P%d: 164 epochs, acceleration enabled\n', P);
        timer = tic;
        result = sessionPrunePNNN(dense.denseFit, features, targets, options);
        seconds = toc(timer); finalRng = rng;
        % Save immediately so analysis failures never require another fit.
        save(fullfile(out, sprintf('accelerated_P%04d.mat', P)), 'result', 'seconds', 'finalRng', '-v7.3');
        fprintf('DONE P%d: %.3f s; RNG exact %d; cache hit %.6f%%\n', ...
            P, seconds, isequal(finalRng, expectedRng), result.diagnostic.hitRate);
    end
    clear features targets dense D S result
    analyzeExtendedValidation(out);
    fprintf('VALIDATION COMPLETE: %s\n', out);
end
