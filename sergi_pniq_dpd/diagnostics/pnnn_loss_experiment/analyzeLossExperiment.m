function analyzeLossExperiment(out)
% ANALYZELOSSEXPERIMENT Evaluate the saved fit only; never trains.
here=fileparts(mfilename('fullpath')); root=fileparts(fileparts(here));
old=path; c=onCleanup(@() path(old)); addpath(genpath(fullfile(root,'toolbox')));
A=load(fullfile(out,'experimental.mat')); folder=A.provenance.sourceFolder;
S=load(fullfile(folder,'experiment.mat')); B=load(fullfile(folder,'pnnn_target_0310.mat'));
st=A.provenance.normalization;
[f,~,r]=buildPhaseNormDataset(S.x,S.y,S.cfg.pnnn.M,S.cfg.pnnn.orders,S.cfg.pnnn.featMode,S.cfg.pnnn);
prediction=predictPNNN(A.result.network,(f.'-st.muX)./st.sigmaX,st,r(:)); clear f
r=r(:);
assert(isequal(A.result.masks,B.point.model.masks));
assert(A.result.counts.activeWeightParams==296 && A.result.counts.activeBiasParams==14);
assert(isequal(A.result.network.State,B.point.model.network.State));
assert(isequal(A.result.network.Learnables(:,1:2),B.point.model.network.Learnables(:,1:2)));
for k=1:height(A.result.network.Learnables)
    v=extractdata(A.result.network.Learnables.Value{k}); b=extractdata(B.point.model.network.Learnables.Value{k});
    assert(isequal(size(v),size(b)) && strcmp(class(v),class(b)) && all(v(~A.result.masks{k})==0));
end
flops=countSparsePNNNFLOPs(S.cfg.names.pnnn,84,12,S.cfg.pnnn.M,S.cfg.pnnn.orders,296,14);
assert(flops.FLOPsPerSample==B.point.row.FLOPsPerSample);
pred={B.point.fullSignalPrediction,prediction}; names=["Historical","Physical loss"];
sets={S.split.identificationIndices,S.split.evaluationIndices,S.split.fullSignalIndices};
domains=["Identification","Development complement","Full signal"]; metrics=table(); bins=table(); signal=table();
[~,ampOrder]=sort(abs(S.x)); edges=round(linspace(0,numel(S.x),11));
for k=1:2
    p=double(pred{k}(:)); assert(all(isfinite(p)) && numel(p)==numel(S.y));
    for j=1:3
        ix=sets{j}; e=r(ix).*(p(ix)-S.y(ix));
        i=mean(real(e).^2); q=mean(imag(e).^2);
        metrics=[metrics;table(names(k),domains(j),nmseComplexDb(S.y(ix),p(ix)),i,q, ...
            i/st.sigmaY(1)^2,q/st.sigmaY(2)^2,i/(i+q),q/(i+q), ...
            (i/st.sigmaY(1)^2+q/st.sigmaY(2)^2)/2,(i+q)/sum(st.sigmaY.^2), ...
            'VariableNames',{'Model','Domain','NMSE','PhysicalMSEI','PhysicalMSEQ','NormalizedMSEI','NormalizedMSEQ', ...
            'ErrorShareI','ErrorShareQ','HistoricalLoss','PhysicalLoss'})]; %#ok<AGROW>
    end
    e=abs(p-S.y).^2;
    for j=1:10
        ix=ampOrder(edges(j)+1:edges(j+1));
        bins=[bins;table(names(k),j,numel(ix),min(abs(S.x(ix))),max(abs(S.x(ix))),mean(e(ix)),mean(sqrt(e(ix))), ...
            nmseComplexDb(S.y(ix),p(ix)),sum(e(ix))/sum(e),sum(abs(S.y(ix)).^2)/sum(abs(S.y).^2), ...
            'VariableNames',{'Model','Decile','Count','MinAmplitude','MaxAmplitude','MSE','MAE','NMSE','ErrorShare','TargetEnergyShare'})]; %#ok<AGROW>
    end
    signal=[signal;table(names(k),sqrt(mean(abs(p).^2)),10*log10(mean(abs(p).^2)),10*log10(max(abs(p).^2)/mean(abs(p).^2)), ...
        max(abs(p)),norm(p-S.y)/norm(S.y),norm(p-double(pred{1}))/norm(double(pred{1})), ...
        flops.FLOPsPerSample,'VariableNames',{'Model','RMS','MeanPowerDbNative','PAPRDb','PeakMagnitude','RelativeErrorTarget','RelativeChangeBaseline','HistoricalFLOPs'})]; %#ok<AGROW>
end
delta=metrics(4:6,{'Domain','NMSE','PhysicalMSEI','PhysicalMSEQ'});
delta.NMSE=delta.NMSE-metrics.NMSE(1:3); delta.PhysicalMSEI=delta.PhysicalMSEI-metrics.PhysicalMSEI(1:3);
delta.PhysicalMSEQ=delta.PhysicalMSEQ-metrics.PhysicalMSEQ(1:3);
writetable(metrics,fullfile(out,'comparison.csv')); writetable(delta,fullfile(out,'delta_experimental_minus_baseline.csv'));
writetable(bins,fullfile(out,'amplitude.csv')); writetable(signal,fullfile(out,'signals.csv'));
model=B.point.model; model.network=A.result.network; model.counts=A.result.counts;
save(fullfile(out,'inference.mat'),'prediction','model','metrics','signal','-v7.3');
disp(metrics); disp(delta); disp(signal); fprintf('ANALYSIS COMPLETE %s\n',out);
end
