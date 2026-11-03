function testIntegration()
% TESTINTEGRATION Check production acceleration and one-budget sweep resume.
% No inputs. Uses saved scientific data read-only; writes a unique fixture here.
    here = fileparts(mfilename('fullpath')); root = fileparts(fileparts(here));
    oldPath = path; cleanup = onCleanup(@() path(oldPath));
    addpath(fullfile(root,'config'), fullfile(root,'DPD'), genpath(fullfile(root,'toolbox')));
    out = tempname(here); mkdir(out); mkdir(fullfile(out,'results'));
    diary(fullfile(out,'integration.log')); diaryCleanup = onCleanup(@() diary('off'));
    fprintf('OUTPUT: %s\nMATLAB: %s\n',out,version);
    source = fullfile(root,'results','dpd_sweep','tpf1484cb1_eb1d_4fe1_9d7e_13899ee8f7e5');
    S = load(fullfile(source,'experiment.mat'));
    D = load(fullfile(source,'sweep_dense_source.mat'));
    C = load(fullfile(source,'pnnn_target_0310.mat'));
    defaults = getComparisonConfig(root); assert(isequal(defaults.pruning.useAcceleration,false));
    assert(~isfield(S.cfg.pruning,'useAcceleration'));
    assert(~isfield(D.denseSource.runtimeConfig.pruning,'useAcceleration'));
    assert(D.denseSource.fineTuneEpochs == 164);

    % Small warmups verify missing=false and preserve epoch-selection execution.
    [f,t,~] = buildPhaseNormDataset(S.x,S.y,S.cfg.pnnn.M,S.cfg.pnnn.orders,S.cfg.pnnn.featMode,S.cfg.pnnn);
    f=f.'; t=t.'; options = struct('Mode',"fixed-epochs",'TrainingRows',S.split.identificationIndices, ...
        'ValidationRows',[],'NNSeed',S.cfg.pnnn.nnSeed,'TargetActiveParameters',310,'FineTuneEpochs',1, ...
        'Config',D.denseSource.runtimeConfig);
    options.Config.training.verbose = false;
    missing = pruneAndFineTunePNNN(D.denseSource.denseFit,f,t,options); missingRng=rng;
    options.Config.pruning.useAcceleration=false;
    disabled = pruneAndFineTunePNNN(D.denseSource.denseFit,f,t,options);
    assert(isequal(missing.network.Learnables,disabled.network.Learnables) && ...
        isequal(missing.masks,disabled.masks) && isequal(missingRng,rng));
    options.Config.pruning.useAcceleration=true;
    pruneAndFineTunePNNN(D.denseSource.denseFit,f,t,options); % Warm accelerated execution.
    options.Mode="select-epochs"; options.ValidationRows=S.split.evaluationIndices(1:1024);
    options.Config.pruning.fineTuneEpochs=1;
    selectedOn = pruneAndFineTunePNNN(D.denseSource.denseFit,f,t,options); selectionRng=rng;
    options.Config.pruning.useAcceleration=false;
    selectedOff = pruneAndFineTunePNNN(D.denseSource.denseFit,f,t,options);
    assert(isequal(selectedOn.network.Learnables,selectedOff.network.Learnables) && ...
        selectedOn.bestEpoch==selectedOff.bestEpoch && isequal(selectionRng,rng));
    fprintf('PASS default/missing option and unchanged epoch-selection controls.\n');
    clear f t missing disabled selectedOn selectedOff D

    % Use real P310 linear checkpoint slices, without fitting either family.
    L = load(fullfile(source,'linear_sweep.mat'),'linear');
    index = find(S.cfg.sweep.parameterGrid == 310); assert(isscalar(index));
    linear = struct('complexTable',L.linear.complexTable(index,:), ...
        'pniqTable',L.linear.pniqTable(index,:), 'predictions',struct( ...
        'complexFull',L.linear.predictions.complexFull(:,index), ...
        'pniqFull',L.linear.predictions.pniqFull(:,index)));
    clear L
    B = load(fullfile(source,'models_P0310.mat'),'bundle');
    linearModels = B.bundle.models(1:2); clear B
    points=cell(1,2); finalRng=cell(1,2); summary=table();
    for mode=1:2
        accelerated = mode==2;
        folder=fullfile(out,'results',sprintf('mode_%d',accelerated)); mkdir(folder);
        cfg=S.cfg; cfg.sweep.parameterGrid=310; cfg.dpd.exportFigures=false;
        if accelerated, cfg.pruning.useAcceleration=true; end % Legacy missing field is the original control.
        x=S.x; y=S.y; split=S.split; provenance=S.provenance;
        save(fullfile(folder,'experiment.mat'),'cfg','x','y','split','provenance','-v7.3');
        save(fullfile(folder,'linear_sweep.mat'),'linear','linearModels','-v7.3');
        copyfile(fullfile(source,'fixed_lambda_linear_sweep.mat'),folder);
        copyfile(fullfile(source,'sweep_dense_source.mat'),folder);
        denseHash=fileHash(fullfile(folder,'sweep_dense_source.mat'));
        fprintf('START production P310 accelerated=%d, 164 epochs\n',accelerated);
        timer=tic; logText=evalc('sweep=runDPDSweep(folder);'); totalSeconds=toc(timer);
        finalRng{mode}=rng; fprintf('%s',logText);
        assert(contains(logText,'Dense PNNN: reused from checkpoint'));
        assert(~contains(logText,'trainDensePNNN'));
        token=regexp(logText,'Fine-tuning: ([0-9.]+) s','tokens','once');
        fineTuneSeconds=str2double(token{1});
        assert(strcmp(denseHash,fileHash(fullfile(folder,'sweep_dense_source.mat'))));
        saved=load(fullfile(folder,'pnnn_target_0310.mat')); points{mode}=saved.point;
        bundle=load(fullfile(folder,'models_P0310.mat'),'bundle');
        assert(isequal(bundle.bundle.models{3}.network.Learnables,saved.point.model.network.Learnables));
        assert(isequal(bundle.bundle.models{3}.masks,saved.point.model.masks));
        assert(isequal(fieldnames(bundle.bundle.models{3}),fieldnames(C.point.model)));
        assert(isequaln(sweep.results.FullSignalNMSEdB(3),saved.point.row.FullSignalNMSEdB));
        assert(saved.point.row.FineTuneEpochs==164);
        files={'experiment.mat','linear_sweep.mat','fixed_lambda_linear_sweep.mat', ...
            'sweep_dense_source.mat','pnnn_target_0310.mat','models_P0310.mat'};
        before=cellfun(@(name) fileHash(fullfile(folder,name)),files,'UniformOutput',false);
        beforeRng=rng; resumeLog=evalc('resumed=runDPDSweep(folder);');
        after=cellfun(@(name) fileHash(fullfile(folder,name)),files,'UniformOutput',false);
        assert(isequal(before,after) && isequal(beforeRng,rng));
        assert(isequaln(sweep.results,resumed.results));
        assert(contains(resumeLog,'Dense PNNN: skipped (all P checkpoints reused)'));
        assert(contains(resumeLog,'P=310: reused from checkpoint'));
        summary=[summary;table(accelerated,totalSeconds,fineTuneSeconds, ...
            'VariableNames',{'Accelerated','PipelineSeconds','FineTuneSecondsRounded'})]; %#ok<AGROW>
        fprintf('PASS mode=%d checkpoint creation, exact reload and no-training resume.\n',accelerated);
        save(fullfile(out,sprintf('mode_%d.mat',accelerated)),'totalSeconds','fineTuneSeconds','logText','resumeLog');
    end
    a=points{1}; b=points{2};
    assert(isequal(a.model.network.Learnables,C.point.model.network.Learnables));
    assert(isequal(a.fullSignalPrediction,C.point.fullSignalPrediction));
    assert(isequal(a.model.masks,b.model.masks) && isequal(finalRng{1},finalRng{2}));
    assert(isequal(a.model.network.State,b.model.network.State));
    wa=[]; wb=[];
    for k=1:height(a.model.network.Learnables)
        va=double(extractdata(a.model.network.Learnables.Value{k}));
        vb=double(extractdata(b.model.network.Learnables.Value{k})); mask=a.model.masks{k};
        assert(all(va(~mask)==0) && all(vb(~mask)==0));
        wa=[wa;va(:)]; wb=[wb;vb(:)]; %#ok<AGROW>
    end
    predictionRelativeL2=norm(double(b.fullSignalPrediction)-double(a.fullSignalPrediction))/norm(double(a.fullSignalPrediction));
    nmseDelta=b.row.FullSignalNMSEdB-a.row.FullSignalNMSEdB;
    weightMaxAbs=max(abs(wb-wa)); weightRelativeL2=norm(wb-wa)/norm(wa);
    assert(predictionRelativeL2<1e-5 && abs(nmseDelta)<1e-4);
    assert(a.model.counts.activeWeightParams+a.model.counts.activeBiasParams==310);
    assert(b.model.counts.activeWeightParams+b.model.counts.activeBiasParams==310);
    experimental=load(fullfile(root,'diagnostics','session_acceleration','tp705818e5_a36d_45e4_ae24_88e83faabad1','run_05.mat'));
    assert(isequal(b.model.network.Learnables,experimental.learnables));
    assert(isequal(finalRng{2},experimental.finalRng));
    comparison=table(predictionRelativeL2,nmseDelta,weightMaxAbs,weightRelativeL2);
    writetable(summary,fullfile(out,'timing.csv')); writetable(comparison,fullfile(out,'comparison.csv'));
    save(fullfile(out,'comparison.mat'),'summary','comparison','finalRng');
    disp(summary); disp(comparison);
    checkcode(fullfile(root,'config','getComparisonConfig.m'));
    checkcode(fullfile(root,'toolbox','pnnn','pruneAndFineTunePNNN.m'));
    checkcode(fullfile(root,'toolbox','pnnn','fitSparsePNNN.m'));
    fprintf('ALL INTEGRATION CHECKS PASSED: %s\n',out);
end

function hash=fileHash(filename)
% SHA256 of a diagnostic checkpoint, used to verify byte-preserving resume.
    fid=fopen(filename,'rb'); assert(fid~=-1); closer=onCleanup(@() fclose(fid));
    bytes=fread(fid,Inf,'*uint8'); digest=java.security.MessageDigest.getInstance('SHA-256');
    digest.update(bytes); hash=reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]);
end
