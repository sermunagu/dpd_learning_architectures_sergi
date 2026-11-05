function analyzeMixedLoss(fitFolder)
% ANALYZEMIXEDLOSS Compare one saved mixed fit with three frozen references.
% Input: completed fit directory. Output: unique analysis folder; no training.
here=fileparts(mfilename('fullpath')); root=fileparts(fileparts(here));
old=path; pc=onCleanup(@() path(old));
addpath(here,fullfile(root,'diagnostics','pnnn_loss_validation'),genpath(fullfile(root,'toolbox')));
out=tempname(fitFolder); mkdir(out); diary(fullfile(out,'analysis.log')); dc=onCleanup(@() diary('off'));
A=load(fullfile(fitFolder,'experimental.mat')); P=load(fullfile(fitFolder,'protocol.mat'));
assert(isequal(A.finalRng,P.expectedRng) && A.provenance.alpha==0.5);
folder=A.provenance.sourceFolder; S=load(fullfile(folder,'experiment.mat'));
B=load(fullfile(folder,'pnnn_target_0310.mat'));
prior=fullfile(root,'diagnostics','pnnn_loss_experiment','tp15ee449b_7a1a_4442_a6ae_cdefa2453e8a');
F=load(fullfile(prior,'inference.mat'));
assert(isequal(A.result.masks,B.point.model.masks,F.model.masks));
assert(isequal(A.result.network.Connections,B.point.model.network.Connections));
assert(isequal(A.result.network.State,B.point.model.network.State));
assert(isequal(A.result.network.Learnables(:,1:2),B.point.model.network.Learnables(:,1:2)));
for k=1:numel(A.result.network.Layers)
    assert(strcmp(class(A.result.network.Layers(k)),class(B.point.model.network.Layers(k))));
end
for k=1:height(A.result.network.Learnables)
    v=extractdata(A.result.network.Learnables.Value{k}); b=extractdata(B.point.model.network.Learnables.Value{k});
    assert(isequal(size(v),size(b)) && strcmp(class(v),class(b)) && all(isfinite(v),'all'));
    assert(all(v(~A.result.masks{k})==0) && nnz(v)==nnz(A.result.masks{k}));
end
cfg=B.point.model.featureConfig; stats=A.provenance.normalization;
[f,~,r]=buildPhaseNormDataset(S.x,zeros(size(S.x)),cfg.M,cfg.orders,cfg.featMode,cfg);
prediction=predictPNNN(A.result.network,(f.'-stats.muX)./stats.sigmaX,stats,r); clear f
assert(iscolumn(prediction) && numel(prediction)==numel(S.y) && all(isfinite(prediction)));
model=B.point.model; model.network=A.result.network; model.counts=A.result.counts;
save(fullfile(out,'inference.mat'),'prediction','model','-v7.3');
L=load(fullfile(folder,'linear_sweep.mat'),'linear'); budgetIndex=find(S.cfg.sweep.parameterGrid==310);
pred={double(B.point.fullSignalPrediction),double(prediction),double(F.prediction),double(L.linear.predictions.pniqFull(:,budgetIndex))};
clear L F prediction
names=["Historical alpha=0","Mixed alpha=0.5","Physical alpha=1","PN-IQ-GMP"];
sets={S.split.identificationIndices,S.split.evaluationIndices,S.split.fullSignalIndices};
domains=["Identification","Development complement","Full development capture"];
metrics=table(); bins=table(); deltas=table();
[~,ord]=sort(abs(S.x)); edges=round(linspace(0,numel(S.x),11));
for k=1:4
    p=pred{k}; totalError=sum(abs(p-S.y).^2); totalEnergy=sum(abs(S.y).^2);
    for j=1:3
        ix=sets{j}; row=errorMetrics(S.x(ix),S.y(ix),p(ix));
        row.AngularRMSEDeg=angularRMSE(p(ix),S.y(ix));
        row.NormalizedLoss=(row.MSEI/stats.sigmaY(1)^2+row.MSEQ/stats.sigmaY(2)^2)/2;
        row.PhysicalLoss=row.MSE/sum(stats.sigmaY.^2);
        row.MixedLoss=(row.NormalizedLoss+row.PhysicalLoss)/2;
        metrics=[metrics;addvars(row,names(k),domains(j),'Before',1,'NewVariableNames',{'Model','Domain'})]; %#ok<AGROW>
    end
    for b=1:10
        ix=ord(edges(b)+1:edges(b+1)); row=errorMetrics(S.x(ix),S.y(ix),p(ix));
        row.AngularRMSEDeg=angularRMSE(p(ix),S.y(ix));
        row.ErrorShare=sum(abs(p(ix)-S.y(ix)).^2)/totalError;
        row.ReferenceEnergyShare=sum(abs(S.y(ix)).^2)/totalEnergy;
        row.MinAmplitude=min(abs(S.x(ix))); row.MaxAmplitude=max(abs(S.x(ix)));
        bins=[bins;addvars(row,names(k),b,'Before',1,'NewVariableNames',{'Model','Decile'})]; %#ok<AGROW>
    end
end
for k=2:4
    for j=1:3
        b=metrics(j,:); v=metrics((k-1)*3+j,:);
        deltas=[deltas;table(names(k),domains(j),v.NMSE-b.NMSE,100*(v.MSE/b.MSE-1), ...
            100*(v.MSEI/b.MSEI-1),100*(v.MSEQ/b.MSEQ-1),100*(v.MAE/b.MAE-1), ...
            100*(v.AngularRMSEDeg/b.AngularRMSEDeg-1),'VariableNames', ...
            {'Model','Domain','NMSEDeltaDb','MSEChangePct','IChangePct','QChangePct','MAEChangePct','AngularChangePct'})]; %#ok<AGROW>
    end
end
decision=struct('developmentNMSEGainDb',metrics.NMSE(2)-metrics.NMSE(5), ...
    'developmentQChangePct',100*(metrics.MSEQ(5)/metrics.MSEQ(2)-1));
decision.pass=decision.developmentNMSEGainDb>=0.10 && decision.developmentQChangePct<=10;
flops=countSparsePNNNFLOPs(S.cfg.names.pnnn,84,12,S.cfg.pnnn.M,S.cfg.pnnn.orders,296,14);
assert(flops.FLOPsPerSample==B.point.row.FLOPsPerSample);
% Recheck existing metrics without repeating their training or inference.
oldMetrics=readtable(fullfile(root,'diagnostics','pnnn_loss_validation', ...
    'tpa1c233b4_dbd3_4fd6_b4ed_58dfa5b91317','metrics.csv'));
assert(max(abs(metrics.NMSE([1:3 7:12])-oldMetrics.NMSE))<1e-10);
assert(max(abs(metrics.MSE([1:3 7:12])-oldMetrics.MSE))<1e-18);
writetable(metrics,fullfile(out,'metrics.csv')); writetable(bins,fullfile(out,'amplitude.csv'));
writetable(deltas,fullfile(out,'deltas_vs_historical.csv'));
save(fullfile(out,'analysis.mat'),'metrics','bins','deltas','decision','flops','-v7.3');
disp(metrics); disp(deltas); disp(decision); fprintf('Historical FLOPs per sample: %d\n',flops.FLOPsPerSample);
fig=figure('Visible','off','Position',[100 100 1100 750]); tiledlayout(2,2);
nexttile; hold on; for k=1:4, plot(1:10,bins.NMSE((k-1)*10+(1:10)),'-o'); end
title('Complex NMSE by input amplitude'); ylabel('dB'); xlabel('Decile'); grid on; legend(names,'Location','southwest');
nexttile; hold on; for k=2:3, plot(1:10,100*(bins.MSEQ((k-1)*10+(1:10))./bins.MSEQ(1:10)-1),'-o'); end
yline(10,'k--','Proposed Q limit'); title('Q MSE change vs historical'); ylabel('Percent'); xlabel('Decile'); legend(names(2:3),'Location','best'); grid on;
nexttile; hold on; for k=1:4, plot(1:10,bins.AngularRMSEDeg((k-1)*10+(1:10)),'-o'); end
title('Reference-energy-weighted phase error'); ylabel('RMSE (degrees)'); xlabel('Decile'); grid on;
nexttile; hold on; for k=1:4, plot(1:10,100*bins.ErrorShare((k-1)*10+(1:10)),'-o'); end
plot(1:10,100*bins.ReferenceEnergyShare(1:10),'k--'); title('Error share (dashed: target energy)'); ylabel('Percent'); xlabel('Decile'); grid on;
sgtitle('One alpha=0.5 fit - October development data only');
exportgraphics(fig,fullfile(out,'comparison.png'),'Resolution',160); close(fig);
fprintf('ANALYSIS COMPLETE %s\n',out);
end

function value=angularRMSE(p,y)
% Reference-energy-weighted wrapped angular error, in degrees; not RF EVM.
ix=abs(y)>0; assert(all(abs(p(ix))>0),'Predicted phase undefined at zero.');
value=sqrt(sum(abs(y(ix)).^2.*angle(p(ix).*conj(y(ix))).^2)/sum(abs(y(ix)).^2))*180/pi;
end
