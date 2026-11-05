function verifySavedReadoutLS(out)
% VERIFYSAVEDREADOUTLS Verify serialization and guards without another fit.
% Input: completed run folder. Writes a JSON summary and validation log once.
    here=fileparts(mfilename('fullpath')); root=fileparts(fileparts(here));
    oldPath=path; restorePath=onCleanup(@() path(oldPath));
    addpath(here,genpath(fullfile(root,'toolbox')));
    assert(~isfile(fullfile(out,'saved_verification.json')) && ~isfile(fullfile(out,'saved_verification.log')));
    diary(fullfile(out,'saved_verification.log')); dc=onCleanup(@() diary('off'));
    F=load(fullfile(out,'readout_model.mat')); I=load(fullfile(out,'inference.mat'));
    Q=load(fullfile(out,'prepared.mat'),'model','Z','r','checks','provenance');
    A=load(fullfile(out,'analysis.mat'),'decision','comparisonChecks');
    rngBefore=rng;
    reconstructed=predictPNNN(F.model.network,Q.Z,F.model.normalization,Q.r);
    assert(isequal(reconstructed,I.prediction)); clear reconstructed
    assert(isequal(F.model.network.Learnables.Value(1:2),Q.model.network.Learnables.Value(1:2)));
    assert(isequal(F.model.masks,Q.model.masks) && isequal(F.model.normalization,Q.model.normalization));
    assert(isequal(rngBefore,rng));
    guards=false(3,1);
    try
        runReadoutLS('fit',out);
    catch exception
        guards(1)=contains(exception.message,'A real fit was already started.');
    end
    try
        runReadoutLS('preflight');
    catch exception
        guards(2)=contains(exception.message,'A fit was already started.');
    end
    try
        analyzeReadoutLS(out);
    catch exception
        guards(3)=contains(exception.message,'Analysis already exists; use saved results.');
    end
    assert(all(guards));
    summary=struct('savedPredictionExact',true,'hiddenWeightsExact',true, ...
        'masksExact',true,'normalizationExact',true,'rngExact',isequal(rngBefore,rng), ...
        'repeatFitGuard',guards(1),'repeatPreflightGuard',guards(2),'repeatAnalysisGuard',guards(3), ...
        'fitSeconds',F.fitSeconds,'preflight',Q.checks,'verification',I.verification, ...
        'decision',A.decision,'comparisonChecks',A.comparisonChecks,'provenance',F.provenance);
    for c=1:2
        singular=F.fit.outputs{c}.singularValues;
        summary.singularExtremes(c,:)=[singular(1),singular(end)];
    end
    fid=fopen(fullfile(out,'saved_verification.json'),'w','n','UTF-8'); assert(fid>=0);
    closeFile=onCleanup(@() fclose(fid)); fprintf(fid,'%s\n',jsonencode(summary,PrettyPrint=true));
    disp(I.verification); disp(A.decision); fprintf('Saved-model equality and all no-overwrite guards PASS.\n');
    files=dir(fullfile(here,'*.m'));
    for k=1:numel(files)
        fprintf('CHECKCODE %s\n',files(k).name);
        issues=checkcode(fullfile(here,files(k).name),'-id');
        for j=1:numel(issues), fprintf('Line %d: %s\n',issues(j).line,issues(j).message); end
        if isempty(issues), fprintf('No messages.\n'); end
    end
end
