function diagnose()
% DIAGNOSE Read-only PNNN root-cause analysis. No training or RF calls.
% Writes derived tables into a fresh directory beside this script.
here=fileparts(mfilename('fullpath')); root=fileparts(fileparts(here));
old=path; cleanup=onCleanup(@() path(old)); addpath(genpath(fullfile(root,'toolbox')));
out=tempname(here); mkdir(out); diary(fullfile(out,'analysis.log')); dc=onCleanup(@() diary('off'));
fprintf('OUTPUT %s\nMATLAB %s\n',out,version);
dirs=dir(fullfile(root,'results','dpd_sweep','*','experiment.mat')); inventory=table();
for j=1:numel(dirs)
    z=load(fullfile(dirs(j).folder,dirs(j).name),'cfg','provenance','x');
    inventory=[inventory;table(string(dirs(j).folder),string(z.provenance.sourceFile),numel(z.x), ...
        string(mat2str(z.cfg.sweep.parameterGrid)),'VariableNames',{'Folder','Source','Samples','Grid'})]; %#ok<AGROW>
end
writetable(inventory,fullfile(out,'inventory.csv')); disp(inventory);
folder=fullfile(root,'results','dpd_sweep','tpf1484cb1_eb1d_4fe1_9d7e_13899ee8f7e5');
S=load(fullfile(folder,'experiment.mat')); D=load(fullfile(folder,'sweep_dense_source.mat'));
B=load(fullfile(folder,'models_P0310.mat')); R=load(fullfile(folder,'pnnn_target_0310.mat'));
[F,T,rot]=buildPhaseNormDataset(S.x,S.y,S.cfg.pnnn.M,S.cfg.pnnn.orders,S.cfg.pnnn.featMode,S.cfg.pnnn);
F=F.'; T=T.'; rot=rot(:); st=D.denseSource.denseFit.normalization; Z=(F-st.muX)./st.sigmaX;
id=S.split.identificationIndices; ev=S.split.evaluationIndices;
assert(isequal(st,B.bundle.models{3}.normalization));
assert(isequal(mean(F(id,:),1),st.muX)); sx=std(F(id,:),0,1); sx(sx==0)=1; assert(isequal(sx,st.sigmaX));
assert(isequal(mean(T(id,:),1),st.muY)); assert(isequal(std(T(id,:),0,1),st.sigmaY));
dense=predictPNNN(D.denseSource.denseFit.network,Z,st,rot);
sparse=predictPNNN(B.bundle.models{3}.network,Z,st,rot); assert(isequal(sparse,R.point.fullSignalPrediction));
raw=load(fullfile(fileparts(root),'results','experimentosSergi20261023','experiment20261023T102742_xy.mat'));
assert(isequal(double(raw.x(:))-mean(double(raw.x(:))),S.x));
assert(isequal(double(raw.y(:))-mean(double(raw.y(:))),S.y));
dpd=applyDPDModels(B.bundle,raw.x); assert(isequal(dpd(3).yvalmod,sparse));
pred={dpd(1).yvalmod,dpd(2).yvalmod,sparse,dense}; names=["GMP-DOMP","PN-IQ-GMP","PNNN P310","PNNN dense"];
metrics=table(); bins=table(); temporal=table(); concentration=table();
for k=1:4
    p=double(pred{k}); e=abs(p-S.y).^2;
    metrics=[metrics;table(names(k),nmseComplexDb(S.y,p),nmseComplexDb(S.y(id),p(id)), ...
        nmseComplexDb(S.y(ev),p(ev)),mean(e),'VariableNames',{'Model','FullNMSE','IdentificationNMSE','EvaluationNMSE','MSE'})]; %#ok<AGROW>
    sorted=sort(e,'descend'); concentration=[concentration;table(names(k),sum(sorted(1:ceil(numel(e)*.01)))/sum(e), ...
        sum(sorted(1:ceil(numel(e)*.001)))/sum(e),'VariableNames',{'Model','Top1PercentErrorShare','TopPoint1PercentErrorShare'})]; %#ok<AGROW>
    for domain=1:2
        amp=abs(S.x); if domain==2, amp=abs(S.y); end
        [~,order]=sort(amp); edges=round(linspace(0,numel(amp),11));
        for b=1:10
            ix=order(edges(b)+1:edges(b+1));
            bins=[bins;table(names(k),domain,b,numel(ix),min(amp(ix)),max(amp(ix)),mean(e(ix)), ...
                mean(sqrt(e(ix))),nmseComplexDb(S.y(ix),p(ix)),sum(e(ix))/sum(e),sum(abs(S.y(ix)).^2)/sum(abs(S.y).^2), ...
                'VariableNames',{'Model','AmplitudeDomain','Decile','Count','MinAmplitude','MaxAmplitude','MSE','MAE','NMSE','ErrorShare','TargetEnergyShare'})]; %#ok<AGROW>
        end
    end
    edges=round(linspace(0,numel(e),21));
    for b=1:20
        ix=(edges(b)+1:edges(b+1)).'; temporal=[temporal;table(names(k),b,nmseComplexDb(S.y(ix),p(ix)), ...
            mean(e(ix)),sum(e(ix))/sum(e),'VariableNames',{'Model','Block','NMSE','MSE','ErrorShare'})]; %#ok<AGROW>
    end
end
writetable(metrics,fullfile(out,'metrics.csv')); writetable(bins,fullfile(out,'amplitude.csv'));
writetable(temporal,fullfile(out,'temporal.csv')); writetable(concentration,fullfile(out,'concentration.csv')); disp(metrics);
C=corrcoef(F(id,:)); [a,b]=find(triu(abs(C)>.95,1)); pairs=table(a,b,C(sub2ind(size(C),a,b)),'VariableNames',{'FeatureA','FeatureB','Correlation'});
writetable(pairs,fullfile(out,'correlations.csv'));
feature=table((1:84).',mean(F(id,:),1).',std(F(id,:),0,1).',min(F,[],1).',max(F,[],1).', ...
    max(abs(Z),[],1).','VariableNames',{'Feature','Mean','Std','Min','Max','MaxAbsZ'});
writetable(feature,fullfile(out,'features.csv'));
sv=svd(Z(id,:),0); writetable(table((1:84).',sv,'VariableNames',{'Index','SingularValue'}),fullfile(out,'feature_singular_values.csv'));
acts=table(); connections=table(); layers=table();
for k=1:2
    net=D.denseSource.denseFit.network; label="dense"; if k==2, net=B.bundle.models{3}.network; label="P310"; end
    L=net.Learnables; W=double(extractdata(L.Value{1})); bias=double(extractdata(L.Value{2})); V=double(extractdata(L.Value{3}));
    A=Z*W.'+bias.'; H=1./(1+exp(-A)); deriv=H.*(1-H);
    acts=[acts;table(repmat(label,12,1),(1:12).',mean(abs(A)>4.59511985,1).',mean(abs(A)>6.90675478,1).', ...
        std(H,0,1).',mean(deriv,1).',sqrt(sum(V.^2,1)).'.*mean(deriv,1).', ...
        sum(W~=0,2),sum(V~=0,1).','VariableNames',{'Model','Neuron','Saturation01','Saturation001','ActivationStd','MeanSigmoidDerivative','OutputWeightedSensitivity','ActiveInputs','ActiveOutputs'})]; %#ok<AGROW>
    for r=1:height(L)
        v=double(extractdata(L.Value{r})); layers=[layers;table(label,string(L.Layer(r)),string(L.Parameter(r)),numel(v),nnz(v),max(abs(v(:))),norm(v(:)), ...
            'VariableNames',{'Model','Layer','Parameter','Total','Nonzero','MaxAbs','L2'})]; %#ok<AGROW>
        if k==2, assert(all(v(~B.bundle.models{3}.masks{r})==0)); end
    end
    connections=[connections;table(repmat(label,84,1),(1:84).',sum(W~=0,1).',sqrt(sum(W.^2,1)).', ...
        'VariableNames',{'Model','Feature','ActiveConnections','WeightL2'})]; %#ok<AGROW>
    % Independent algebraic phase restoration; double arithmetic differs from network single arithmetic.
    yn=H*V.'+double(extractdata(L.Value{4})).'; yr=yn.*st.sigmaY+st.muY; manual=conj(rot).*complex(yr(:,1),yr(:,2));
    reference=dense; if k==2, reference=sparse; end
    fprintf('Manual double formula %s prediction relative L2 %.12g\n',label,norm(manual-double(reference))/norm(double(reference)));
end
writetable(acts,fullfile(out,'activations.csv')); writetable(connections,fullfile(out,'connections.csv')); writetable(layers,fullfile(out,'layers.csv'));
fprintf('sigmaY = %.12g %.12g; Q/I loss weight ratio = %.12g\n',st.sigmaY,st.sigmaY(1)^2/st.sigmaY(2)^2);
fprintf('Epochs dense=%d sparse=%d; features type=%s weights type=%s; rank numerical=%d\n',D.denseSource.bestDenseEpoch,D.denseSource.fineTuneEpochs,class(F),class(extractdata(L.Value{1})),rank(Z(id,:)));
% Verify the measured October imitation independently, without replacing its target by centered y.
M=load(fullfile(fileparts(root),'results','experimentosSergi20261023','experiment20261023T102742_DPD_offline_comparison.mat'));
rf=table();
for j=1:numel(M.meas_out)
    q=M.meas_out(j);
    if numel(q.x)==numel(raw.y)
        rf=[rf;table(j,string(q.descr),nmseComplexDb(raw.y,q.x),double(q.performance.NMSE),'VariableNames',{'Index','Description','ImitationNMSE','RecordedRFNMSE'})]; %#ok<AGROW>
    end
end
writetable(rf,fullfile(out,'measured_october.csv')); disp(rf);
% Inventory existing structural-zero experiments rather than assuming the old report is current.
files=dir(fullfile(root,'results','pnnn_phase_experiment','*','comparison.csv'));
for j=1:numel(files), fprintf('EXISTING PHASE EXPERIMENT %s\n',files(j).folder); disp(readtable(fullfile(files(j).folder,files(j).name))); end
save(fullfile(out,'analysis.mat'),'metrics','acts','layers','connections','feature','sv','st','inventory','rf');
fprintf('READ-ONLY DIAGNOSTIC COMPLETE\n');
end
