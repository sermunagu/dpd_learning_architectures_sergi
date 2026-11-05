function analyzeReadoutLS(out)
% ANALYZEREADOUTLS Compare one saved readout refit against frozen references.
% Input: completed run folder. Writes metrics once; never fits any coefficient.
    here=fileparts(mfilename('fullpath')); root=fileparts(fileparts(here));
    oldPath=path; restorePath=onCleanup(@() path(oldPath));
    addpath(here,genpath(fullfile(root,'toolbox')), ...
        fullfile(root,'diagnostics','pnnn_loss_validation'));
    assert(~isfile(fullfile(out,'analysis.mat')) && ~isfile(fullfile(out,'metrics.csv')), ...
        'Analysis already exists; use saved results.');
    diary(fullfile(out,'analysis.log')); dc=onCleanup(@() diary('off'));
    F=load(fullfile(out,'readout_model.mat')); I=load(fullfile(out,'inference.mat'));
    Q=load(fullfile(out,'prepared.mat'),'originalPrediction'); source=F.provenance.source;
    S=load(source.experiment); B=load(source.historical); G=load(source.bundle);
    L=load(source.linear,'linear'); k=find(S.cfg.sweep.parameterGrid==310); assert(isscalar(k));
    predictions={double(B.point.fullSignalPrediction),double(Q.originalPrediction), ...
        double(I.prediction),double(L.linear.predictions.pniqFull(:,k))}; clear L Q
    names=["Historical alpha=0","Mixed alpha=0.5","Mixed alpha=0.5 + readout LS","PN-IQ-GMP"];
    domains=["Identification","Development complement","Full development capture"];
    sets={S.split.identificationIndices,S.split.evaluationIndices,S.split.fullSignalIndices};
    st=F.model.normalization; weights=F.provenance.weights;
    flops=countSparsePNNNFLOPs(S.cfg.names.pnnn,84,12,13,[1 3 5 7],296,14);
    assert(flops.FLOPsPerSample==B.point.row.FLOPsPerSample && flops.FLOPsPerSample==780);
    counts=[B.point.row.ActualRealParameters,310,I.verification.activeParameters, ...
        G.bundle.metrics.ActualRealParameters(2)];
    costs=[flops.FLOPsPerSample,flops.FLOPsPerSample,flops.FLOPsPerSample, ...
        G.bundle.metrics.FLOPsPerSample(2)];
    assert(all(counts==310) && costs(4)==1013);
    metrics=table(); bins=table(); deltas=table(); amplitudeDeltas=table();
    [~,order]=sort(abs(S.x)); edges=round(linspace(0,numel(S.x),11));
    for m=1:4
        p=predictions{m};
        for j=1:3
            ix=sets{j}; row=metricsRow(S.x(ix),S.y(ix),p(ix),st,weights);
            row.ActiveParameters=counts(m); row.AnalyticalFLOPs=costs(m);
            metrics=[metrics;addvars(row,names(m),domains(j),'Before',1, ...
                'NewVariableNames',{'Model','Domain'})]; %#ok<AGROW>
        end
        if m==2 || m==3
            totalError=sum(abs(p-S.y).^2); totalEnergy=sum(abs(S.y).^2);
            for b=1:10
                ix=order(edges(b)+1:edges(b+1)); row=metricsRow(S.x(ix),S.y(ix),p(ix),st,weights);
                row.ErrorShare=sum(abs(p(ix)-S.y(ix)).^2)/totalError;
                row.ReferenceEnergyShare=sum(abs(S.y(ix)).^2)/totalEnergy;
                row.MinAmplitude=min(abs(S.x(ix))); row.MaxAmplitude=max(abs(S.x(ix)));
                bins=[bins;addvars(row,names(m),b,'Before',1, ...
                    'NewVariableNames',{'Model','Decile'})]; %#ok<AGROW>
            end
        end
    end
    oldMetrics=readtable(source.oldMetrics);
    assert(max(abs(metrics.NMSE([1:6 10:12])-oldMetrics.NMSE([1:6 10:12])))<1e-10);
    assert(max(abs(metrics.MSE([1:6 10:12])-oldMetrics.MSE([1:6 10:12])))<1e-18);
    assert(max(abs(metrics.MixedLoss([1:6 10:12])-oldMetrics.MixedLoss([1:6 10:12])))<1e-15);
    csvBins=readtable(source.oldBins); csvBins=csvBins(string(csvBins.Model)=="Mixed alpha=0.5",:);
    prior=load(fullfile(fileparts(source.oldBins),'analysis.mat'),'bins');
    oldBins=prior.bins(string(prior.bins.Model)=="Mixed alpha=0.5",:);
    csvBoundaryRoundtripMaxAbs=max(abs([csvBins.MinAmplitude-oldBins.MinAmplitude; ...
        csvBins.MaxAmplitude-oldBins.MaxAmplitude]));
    assert(isequal(bins.N(1:10),oldBins.N) && isequal(bins.MinAmplitude(1:10),oldBins.MinAmplitude));
    assert(isequal(bins.MaxAmplitude(1:10),oldBins.MaxAmplitude));
    assert(max(abs(bins.MSE(1:10)-oldBins.MSE))<1e-18);
    for j=1:3
        a=metrics(3+j,:); b=metrics(6+j,:); g=metrics(9+j,:);
        row=deltaRow(a,b); row.RemainingGapDb=b.NMSE-g.NMSE;
        row.ClosedDbGapPct=100*(a.NMSE-b.NMSE)/(a.NMSE-g.NMSE);
        row.ClosedMSEGapPct=100*(a.MSE-b.MSE)/(a.MSE-g.MSE);
        deltas=[deltas;addvars(row,domains(j),'Before',1,'NewVariableNames','Domain')]; %#ok<AGROW>
    end
    totalRecovered=metrics.MSE(6)-metrics.MSE(9);
    for b=1:10
        row=deltaRow(bins(b,:),bins(10+b,:));
        row.RecoveredErrorShare=(bins.MSE(b)-bins.MSE(10+b))*bins.N(b)/(numel(S.x)*totalRecovered);
        amplitudeDeltas=[amplitudeDeltas;addvars(row,b,'Before',1,'NewVariableNames','Decile')]; %#ok<AGROW>
    end
    decision=struct('developmentNMSEGainDb',deltas.NMSEGainDb(2), ...
        'developmentQChangePct',deltas.QChangePct(2), ...
        'minimumGainDb',.10,'maximumQIncreasePct',10);
    decision.pass=decision.developmentNMSEGainDb>=.10 && decision.developmentQChangePct<=10;
    assert(metrics.MixedLoss(7)<=metrics.MixedLoss(4)+I.verification.lossRoundingBudget);
    comparisonChecks=struct('savedBaselineMetricsMatch',true,'historicalAmplitudeBinsMatch',true, ...
        'countsAndFLOPsUnchanged',true,'fitAndAnalysisSeparated',true, ...
        'csvBoundaryRoundtripMaxAbs',csvBoundaryRoundtripMaxAbs);
    order=uint32(order);
    save(fullfile(out,'analysis.mat'),'metrics','bins','deltas','amplitudeDeltas','decision', ...
        'flops','order','edges','comparisonChecks','-v7.3');
    writetable(metrics,fullfile(out,'metrics.csv')); writetable(bins,fullfile(out,'amplitude.csv'));
    writetable(deltas,fullfile(out,'deltas_vs_mixed.csv'));
    writetable(amplitudeDeltas,fullfile(out,'amplitude_deltas.csv'));
    disp(metrics); disp(deltas); disp(amplitudeDeltas); disp(decision); disp(comparisonChecks);
    fprintf('ANALYSIS COMPLETE. Frozen development data only.\n%s\n',out);
end

function m=metricsRow(x,y,p,st,weights)
% Extend prior physical metrics without changing their definitions.
    m=errorMetrics(x,y,p);
    m.NormalizedMSEI=m.MSEI/st.sigmaY(1)^2; m.NormalizedMSEQ=m.MSEQ/st.sigmaY(2)^2;
    m.MixedLoss=(weights(1)*m.NormalizedMSEI+weights(2)*m.NormalizedMSEQ)/2;
    m.AmplitudeRMSE=sqrt(mean((abs(p)-abs(y)).^2));
    m.AmplitudeMAE=mean(abs(abs(p)-abs(y))); m.AmplitudeBias=mean(abs(p)-abs(y));
    ix=abs(y)>0; assert(all(abs(p(ix))>0));
    m.AngularRMSEDeg=sqrt(sum(abs(y(ix)).^2.*angle(p(ix).*conj(y(ix))).^2)/sum(abs(y(ix)).^2))*180/pi;
end

function d=deltaRow(a,b)
% Positive NMSEGainDb means improvement; negative percentage means reduction.
    d=table(a.NMSE-b.NMSE,100*(b.MSE/a.MSE-1),100*(b.MSEI/a.MSEI-1), ...
        100*(b.MSEQ/a.MSEQ-1),100*(b.MixedLoss/a.MixedLoss-1),100*(b.MAE/a.MAE-1), ...
        100*(b.AmplitudeRMSE/a.AmplitudeRMSE-1),100*(b.AngularRMSEDeg/a.AngularRMSEDeg-1), ...
        100*(b.RMS/a.RMS-1),b.PAPR-a.PAPR,'VariableNames', ...
        {'NMSEGainDb','MSEChangePct','IChangePct','QChangePct','MixedLossChangePct', ...
        'MAEChangePct','AmplitudeRMSEChangePct','AngularChangePct','RMSChangePct','PAPRChangeDb'});
end
