function verifySavedExperiment(out)
% VERIFYSAVEDEXPERIMENT Audit saved results without performing any training.
% Input: unique experiment folder. Output: verification log and target CSV.
here=fileparts(mfilename('fullpath'));
diary(fullfile(out,'verification.log')); c=onCleanup(@() diary('off'));
A=load(fullfile(out,'experimental.mat'));
P=load(fullfile(out,'protocol.mat'));
S=load(fullfile(A.provenance.sourceFolder,'experiment.mat'));
B=load(fullfile(A.provenance.sourceFolder,'pnnn_target_0310.mat'));
D=load(fullfile(A.provenance.sourceFolder,'sweep_dense_source.mat'));
I=load(fullfile(out,'inference.mat'));
assert(isequal(A.finalRng,P.expectedRng));
assert(isequal(A.result.masks,P.initial.masks,B.point.model.masks));
assert(isequal(A.provenance.normalization,D.denseSource.denseFit.normalization));
assert(A.result.bestEpoch==164);
assert(isequal(I.model.network.Learnables,A.result.network.Learnables));
assert(isequal(I.model.network.Connections,B.point.model.network.Connections));
for k=1:numel(A.result.network.Layers)
    assert(strcmp(class(A.result.network.Layers(k)),class(B.point.model.network.Layers(k))));
end
for k=1:height(A.result.network.Learnables)
    a=extractdata(A.result.network.Learnables.Value{k});
    b=extractdata(B.point.model.network.Learnables.Value{k});
    m=A.result.masks{k};
    assert(all(a(~m)==0) && all(b(~m)==0));
    assert(all(isfinite(a),'all'));
    fprintf('Learnable %d: %s, mask active %d, actual nonzero %d, max weight change %.12g\n', ...
        k,class(a),nnz(m),nnz(a),max(abs(double(a(:))-double(b(:)))));
end
p=S.y;
target=table(sqrt(mean(abs(p).^2)),10*log10(mean(abs(p).^2)), ...
    10*log10(max(abs(p).^2)/mean(abs(p).^2)),max(abs(p)), ...
    'VariableNames',{'RMS','MeanPowerDbNative','PAPRDb','PeakMagnitude'});
writetable(target,fullfile(out,'target_signal.csv'));
disp(target); disp(A.provenance); disp(A.provenance.options.Config);
disp(A.provenance.options.Config.training); disp(A.provenance.options.Config.pruning);
disp(A.result.counts); disp(B.point.model); disp(D.denseSource);
fprintf('Saved fit elapsed %.9f seconds; %d rows, %d epochs, %d recorded permutations.\n', ...
    A.seconds,numel(S.split.identificationIndices),A.result.bestEpoch,size(P.orders,2));
fprintf('Experimental RMS and PAPR are native-scale, pre-CFR; no hardware safety certification.\n');
files=dir(fullfile(here,'*.m'));
for k=1:numel(files)
    fprintf('CHECKCODE %s\n',files(k).name);
    disp(checkcode(fullfile(files(k).folder,files(k).name),'-id'));
end
fprintf('SAVED RESULT VERIFICATION PASS. No training performed.\n');
end
