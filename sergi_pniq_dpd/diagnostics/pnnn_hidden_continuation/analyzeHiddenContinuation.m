function analyzeHiddenContinuation(out)
% ANALYZEHIDDENCONTINUATION Score the one final model without further updates.
% Input: completed run folder. Outputs: endpoint diagnostics and shared metrics.
    here=fileparts(mfilename('fullpath')); root=fileparts(fileparts(here));
    oldPath=path; restorePath=onCleanup(@() path(oldPath));
    addpath(here,genpath(fullfile(root,'toolbox')),fullfile(root,'diagnostics','pnnn_loss_experiment'), ...
        fullfile(root,'diagnostics','pnnn_loss_validation'));
    assert(~isfile(fullfile(out,'analysis.mat')) && ~isfile(fullfile(out,'inference.mat')),'Analysis already exists.');
    diary(fullfile(out,'analysis.log')); dc=onCleanup(@() diary('off')); rngBefore=rng;
    F=load(fullfile(out,'final_model.mat')); provenance=F.provenance; settings=provenance.settings;
    B=load(provenance.source.model); P=load(provenance.source.prediction);
    Q=load(provenance.source.cache,'Z','target','r','id','dev','H','originalPrediction');
    S=load(provenance.originalSource.experiment); G=load(provenance.originalSource.bundle);
    prior=load(fullfile(provenance.source.lsFolder,'analysis.mat'),'metrics','bins','order','edges');
    initialGradient=load(fullfile(out,'gradient_before.mat'));
    before=B.model.network.Learnables; after=F.model.network.Learnables;
    assert(isequal(before.Value(3:4),after.Value(3:4)));
    assert(isequal(B.model.masks,F.model.masks) && isequal(B.model.normalization,F.model.normalization));
    for k=1:4
        v=extractdata(after.Value{k}); old=extractdata(before.Value{k});
        assert(isequal(size(v),size(old)) && strcmp(class(v),class(old)));
        assert(all(v(~F.model.masks{k})==0) && nnz(v)==nnz(F.model.masks{k}));
    end
    prediction=predictPNNN(F.model.network,Q.Z,F.model.normalization,Q.r);
    finalH=predict(F.model.network,Q.Z,Outputs="sigmoid1");
    finalGradient=diagnoseHiddenGradient(F.model,Q.Z(Q.id,:),Q.target(Q.id,:),settings.weights,settings.batchSize,false);
    assert(isequal(rngBefore,rng));
    linear=load(provenance.originalSource.linear,'linear'); index=find(S.cfg.sweep.parameterGrid==310);
    predictions={double(Q.originalPrediction),double(P.prediction),double(prediction), ...
        double(linear.linear.predictions.pniqFull(:,index))}; clear linear
    names=["Mixed alpha=0.5","Mixed + readout LS","Hidden-only continuation","PN-IQ-GMP"];
    sets={Q.id,Q.dev,S.split.fullSignalIndices}; domains=["Identification","Development complement","Full development capture"];
    metrics=table(); bins=table(); deltas=table(); binDeltas=table(); activations=table();
    flops=countSparsePNNNFLOPs(S.cfg.names.pnnn,84,12,13,[1 3 5 7],296,14);
    assert(flops.FLOPsPerSample==780 && G.bundle.metrics.FLOPsPerSample(2)==1013);
    order=double(prior.order); edges=prior.edges;
    for m=1:4
        p=predictions{m};
        for j=1:3
            ix=sets{j}; row=metricRow(S.x(ix),S.y(ix),p(ix),F.model.normalization,settings.weights);
            row.ActiveParameters=310;
            if m==4, row.AnalyticalFLOPs=1013; else, row.AnalyticalFLOPs=780; end
            metrics=[metrics;addvars(row,names(m),domains(j),'Before',1,'NewVariableNames',{'Model','Domain'})]; %#ok<AGROW>
        end
        if m==2 || m==3
            for b=1:10
                ix=order(edges(b)+1:edges(b+1)); row=metricRow(S.x(ix),S.y(ix),p(ix),F.model.normalization,settings.weights);
                row.MinAmplitude=min(abs(S.x(ix))); row.MaxAmplitude=max(abs(S.x(ix)));
                row.ErrorShare=sum(abs(p(ix)-S.y(ix)).^2)/sum(abs(p-S.y).^2);
                bins=[bins;addvars(row,names(m),b,'Before',1,'NewVariableNames',{'Model','Decile'})]; %#ok<AGROW>
            end
        end
    end
    assert(max(abs(metrics.NMSE([1:6 10:12])-prior.metrics.NMSE(4:12)))<1e-10);
    assert(max(abs(metrics.MSE([1:6 10:12])-prior.metrics.MSE(4:12)))<1e-18);
    assert(max(abs(metrics.MixedLoss([1:6 10:12])-prior.metrics.MixedLoss(4:12)))<1e-15);
    assert(isequal(bins.MinAmplitude(1:10),prior.bins.MinAmplitude(11:20)));
    assert(isequal(bins.MaxAmplitude(1:10),prior.bins.MaxAmplitude(11:20)));
    assert(max(abs(bins.MSE(1:10)-prior.bins.MSE(11:20)))<1e-18);
    for j=1:3
        row=deltaRow(metrics(3+j,:),metrics(6+j,:));
        row.RemainingPNIQGapDb=metrics.NMSE(6+j)-metrics.NMSE(9+j);
        deltas=[deltas;addvars(row,domains(j),'Before',1,'NewVariableNames','Domain')]; %#ok<AGROW>
    end
    for b=1:10
        binDeltas=[binDeltas;addvars(deltaRow(bins(b,:),bins(10+b,:)),b,'Before',1,'NewVariableNames','Decile')]; %#ok<AGROW>
    end
    for j=1:3
        activations=[activations;activationRows(Q.H(sets{j},:),"LS baseline",domains(j)); ...
            activationRows(finalH(sets{j},:),"Hidden continuation",domains(j))]; %#ok<AGROW>
    end
    endpointGradients=table(["LS baseline";"Hidden continuation"], ...
        [initialGradient.diagnostic.loss;finalGradient.loss], ...
        [initialGradient.diagnostic.hiddenActiveL2;finalGradient.hiddenActiveL2], ...
        [initialGradient.diagnostic.hiddenPrunedL2;finalGradient.hiddenPrunedL2], ...
        [initialGradient.diagnostic.outputPermittedL2;finalGradient.outputPermittedL2], ...
        [initialGradient.diagnostic.outputPrunedL2;finalGradient.outputPrunedL2], ...
        'VariableNames',{'Model','NativeMixedLoss','HiddenActiveL2','HiddenPrunedL2','OutputPermittedL2','OutputPrunedL2'});
    parameterChanges=table();
    for k=1:4
        a=double(extractdata(before.Value{k})); b=double(extractdata(after.Value{k}));
        parameterChanges=[parameterChanges;table(string(after.Layer(k)),string(after.Parameter(k)),nnz(b),nnz(a~=b), ...
            norm(b(:)-a(:)),max(abs(b-a),[],'all'),'VariableNames', ...
            {'Layer','Parameter','Active','Changed','ChangeL2','MaxAbsChange'})]; %#ok<AGROW>
    end
    assert(sum(parameterChanges.Active)==310 && all(parameterChanges.Changed(3:4)==0));
    assert(all(isfinite(prediction)) && all(isfinite(finalH),'all'));
    decision=struct('developmentNMSEGainDb',deltas.NMSEGainDb(2),'developmentQChangePct',deltas.QChangePct(2), ...
        'minimumGainDb',.10,'maximumQIncreasePct',10);
    decision.pass=decision.developmentNMSEGainDb>=.10 && decision.developmentQChangePct<=10;
    verification=struct('outputExact',true,'masksExact',true,'normalizationExact',true, ...
        'prunedZerosExact',true,'activeParameters',sum(parameterChanges.Active),'prunedWeights',736, ...
        'allOrdersExact',F.training.everyOrderExact,'expectedRngExact',isequal(F.training.finalRng,provenance.expectedRng), ...
        'analysisRngExact',isequal(rngBefore,rng),'referenceMetricsMatch',true,'amplitudeBinsMatch',true);
    assert(verification.expectedRngExact && verification.analysisRngExact);
    save(fullfile(out,'inference.mat'),'prediction','verification','-v7.3');
    save(fullfile(out,'gradient_after.mat'),'finalGradient','-v7.3');
    save(fullfile(out,'analysis.mat'),'metrics','bins','deltas','binDeltas','activations','endpointGradients', ...
        'parameterChanges','decision','verification','flops','-v7.3');
    writetable(metrics,fullfile(out,'metrics.csv')); writetable(bins,fullfile(out,'amplitude.csv'));
    writetable(deltas,fullfile(out,'deltas_vs_ls.csv')); writetable(binDeltas,fullfile(out,'amplitude_deltas.csv'));
    writetable(activations,fullfile(out,'activations.csv')); writetable(parameterChanges,fullfile(out,'parameter_changes.csv'));
    writetable(endpointGradients,fullfile(out,'gradient_endpoints.csv'));
    writetable(finalGradient.statistics,fullfile(out,'gradient_after.csv'));
    writetable(finalGradient.neurons,fullfile(out,'gradient_neurons_after.csv'));
    disp(metrics); disp(deltas); disp(binDeltas); disp(endpointGradients); disp(parameterChanges); disp(decision);
    fprintf('ANALYSIS COMPLETE. No model update performed.\n%s\n',out);
end

function m=metricRow(x,y,p,st,weights)
% Reuse historical physical metrics and fixed normalized loss definitions.
    m=errorMetrics(x,y,p); m.NormalizedMSEI=m.MSEI/st.sigmaY(1)^2; m.NormalizedMSEQ=m.MSEQ/st.sigmaY(2)^2;
    m.MixedLoss=(weights(1)*m.NormalizedMSEI+weights(2)*m.NormalizedMSEQ)/2;
    m.AmplitudeRMSE=sqrt(mean((abs(p)-abs(y)).^2)); m.AmplitudeMAE=mean(abs(abs(p)-abs(y)));
    m.AmplitudeBias=mean(abs(p)-abs(y)); ix=abs(y)>0; assert(all(abs(p(ix))>0));
    m.AngularRMSEDeg=sqrt(sum(abs(y(ix)).^2.*angle(p(ix).*conj(y(ix))).^2)/sum(abs(y(ix)).^2))*180/pi;
end

function d=deltaRow(a,b)
% Positive NMSE gain means improvement; positive percentages mean increase.
    d=table(a.NMSE-b.NMSE,100*(b.MSE/a.MSE-1),100*(b.MSEI/a.MSEI-1),100*(b.MSEQ/a.MSEQ-1), ...
        100*(b.MixedLoss/a.MixedLoss-1),100*(b.MAE/a.MAE-1),100*(b.AmplitudeRMSE/a.AmplitudeRMSE-1), ...
        100*(b.AngularRMSEDeg/a.AngularRMSEDeg-1),100*(b.RMS/a.RMS-1),b.PAPR-a.PAPR, ...
        'VariableNames',{'NMSEGainDb','MSEChangePct','IChangePct','QChangePct','MixedLossChangePct', ...
        'MAEChangePct','AmplitudeRMSEChangePct','AngularChangePct','RMSChangePct','PAPRChangeDb'});
end

function rows=activationRows(H,label,domain)
% Summarize native sigmoid activations; percentiles use nearest-rank order.
    rows=table(); N=size(H,1);
    for n=1:size(H,2)
        h=double(H(:,n)); sorted=sort(h); q=sorted(max(1,ceil([.01 .05 .5 .95 .99]*N)));
        rows=[rows;table(label,domain,n,N,mean(h),std(h),min(h),max(h),q(1),q(2),q(3),q(4),q(5), ...
            mean(h<.01),mean(h>.99),'VariableNames',{'Model','Domain','Neuron','N','Mean','Std','Min','Max', ...
            'P01','P05','Median','P95','P99','Below01','Above99'})]; %#ok<AGROW>
    end
end
