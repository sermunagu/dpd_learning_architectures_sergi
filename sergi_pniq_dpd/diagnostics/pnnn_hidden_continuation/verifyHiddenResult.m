function verifyHiddenResult(out)
% VERIFYHIDDENRESULT Verify saved predictions, checkpoint invariants and guards.
% Input: completed experiment folder. Writes a JSON/log once; never trains.
    here=fileparts(mfilename('fullpath')); root=fileparts(fileparts(here));
    oldPath=path; restorePath=onCleanup(@() path(oldPath));
    addpath(here,genpath(fullfile(root,'toolbox')),fullfile(root,'diagnostics','pnnn_loss_experiment'));
    assert(~isfile(fullfile(out,'saved_verification.json')) && ~isfile(fullfile(out,'saved_verification.log')));
    diary(fullfile(out,'saved_verification.log')); dc=onCleanup(@() diary('off')); beforeRng=rng;
    F=load(fullfile(out,'final_model.mat')); P=load(fullfile(out,'preflight.mat'));
    I=load(fullfile(out,'inference.mat')); A=load(fullfile(out,'analysis.mat'));
    D=load(fullfile(out,'gradient_before.mat')); E=load(fullfile(out,'gradient_after.mat'));
    B=load(F.provenance.source.model); Q=load(F.provenance.source.cache,'Z','r');
    assert(isequal(predictPNNN(F.model.network,Q.Z,F.model.normalization,Q.r),I.prediction)); clear Q
    assert(isequal(F.model.network.Learnables.Value(3:4),B.model.network.Learnables.Value(3:4)));
    assert(isequal(F.model.masks,B.model.masks) && isequal(F.model.normalization,B.model.normalization));
    settings=F.provenance.settings;
    assert(isequal(F.training.trace.Epoch,(1:164).') && isequal(F.training.trace.Updates,48*(1:164).'));
    rates=settings.initialLearnRate*settings.dropFactor.^floor(((1:164).'-1)/settings.dropPeriod);
    assert(isequal(F.training.trace.LearnRate,rates));
    assert(F.training.iterations==7872 && isequal(F.training.finalRng,F.provenance.expectedRng));
    rng(settings.seed,'twister'); initialRng=rng; rng(beforeRng);
    assert(isequal(F.training.initialRng,initialRng));
    checkFrozenMoments(F.training.average,F.training.averageSquared,F.model.masks);
    checkpoints=table();
    for epoch=[41 82 123]
        C=load(fullfile(out,sprintf('checkpoint_epoch%04d.mat',epoch)));
        exact=isequal(C.network.Learnables.Value(3:4),B.model.network.Learnables.Value(3:4));
        assert(exact && isequal(C.masks,B.model.masks) && C.iteration==48*epoch && C.epoch==epoch);
        assert(isequal(C.settings,settings)); active=0;
        for k=1:4
            v=extractdata(C.network.Learnables.Value{k});
            assert(all(v(~C.masks{k})==0)); active=active+nnz(v);
        end
        assert(active==310); checkFrozenMoments(C.average,C.averageSquared,C.masks);
        checkpoints=[checkpoints;table(epoch,C.iteration,exact,active,'VariableNames', ...
            {'Epoch','Updates','OutputExact','ActiveParameters'})]; %#ok<AGROW>
    end
    guards=false(3,1);
    try, runHiddenContinuation('train',out); catch exception, guards(1)=contains(exception.message,'A real continuation was already started.'); end
    try, runHiddenContinuation('preflight'); catch exception, guards(2)=contains(exception.message,'A real continuation was already started.'); end
    try, analyzeHiddenContinuation(out); catch exception, guards(3)=contains(exception.message,'Analysis already exists.'); end
    assert(all(guards) && isequal(beforeRng,rng));
    summary=struct('savedPredictionExact',true,'outputExact',true,'masksExact',true,'normalizationExact',true, ...
        'rngReadOnly',true,'historicalFinalRngExact',true,'newMomentsStartedEmpty',true, ...
        'frozenMomentsZero',true,'repeatTrainGuard',guards(1),'repeatPreflightGuard',guards(2), ...
        'repeatAnalysisGuard',guards(3),'epochs',164,'updates',7872,'trainingSeconds',F.training.seconds, ...
        'checkpoints',table2struct(checkpoints),'settings',settings,'decision',A.decision, ...
        'verification',I.verification,'synthetic',P.synthetic,'preflight',P.checks, ...
        'gradientEndpoints',table2struct(A.endpointGradients),'parameterChanges',table2struct(A.parameterChanges), ...
        'initialDoubleLoss',D.diagnostic.doubleCheck.loss, ...
        'nativeDoublePredictionRelativeL2',D.diagnostic.doubleCheck.predictionRelativeL2, ...
        'finiteDifferenceMaxDoubleAbsError',max(D.diagnostic.doubleCheck.finiteDifferences.DoubleAbsError), ...
        'finiteDifferenceMaxNativeAbsError',max(D.diagnostic.doubleCheck.finiteDifferences.NativeAbsError), ...
        'finalGradientRngExact',E.finalGradient.rngExact,'provenance',rmfield(F.provenance,{'options','expectedRng'}));
    fid=fopen(fullfile(out,'saved_verification.json'),'w','n','UTF-8'); assert(fid>=0);
    closeFile=onCleanup(@() fclose(fid)); fprintf(fid,'%s\n',jsonencode(summary,PrettyPrint=true));
    writetable(checkpoints,fullfile(out,'checkpoint_verification.csv'));
    disp(checkpoints); disp(A.decision); fprintf('SAVED MODEL, CHECKPOINTS AND GUARDS PASS.\n');
    files=dir(fullfile(here,'*.m'));
    for k=1:numel(files)
        fprintf('CHECKCODE %s\n',files(k).name); issues=checkcode(fullfile(here,files(k).name),'-id');
        for j=1:numel(issues), fprintf('Line %d: %s\n',issues(j).line,issues(j).message); end
        if isempty(issues), fprintf('No messages.\n'); end
    end
end

function checkFrozenMoments(first,second,masks)
% Frozen coordinates have exactly zero new first/second Adam moments.
    for k=1:4
        a=extractdata(first.Value{k}); b=extractdata(second.Value{k});
        if k>=3, ix=true(size(a)); else, ix=~masks{k}; end
        assert(all(a(ix)==0) && all(b(ix)==0));
    end
end
