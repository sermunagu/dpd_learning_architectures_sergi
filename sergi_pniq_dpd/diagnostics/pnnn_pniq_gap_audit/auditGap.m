function auditGap()
% AUDITGAP Inspect frozen representations, stationarity and residual structure.
% No inputs; writes a fresh diagnostics folder. Never fits or updates a model.
here=fileparts(mfilename('fullpath')); root=fileparts(fileparts(here));
old=path; pc=onCleanup(@() path(old)); addpath(here,genpath(fullfile(root,'toolbox')),fullfile(root,'diagnostics','pnnn_loss_validation'));
out=tempname(here); mkdir(out); diary(fullfile(out,'audit.log')); dc=onCleanup(@() diary('off'));
% Synthetic metric, lag convention and Parseval checks before real arrays.
sx=exp(1i*(0:31).')/10; sy=0.9*sx; sp=sy+0.01*conj(sx);
sm=errorMetrics(sx,sy,sp); assert(abs(sm.MSE-sum(abs(fft(sp-sy)).^2)/numel(sx)^2)<1e-15);
assert(isequal(circshift((1:5).',1),[5;1;2;3;4]));
assert(isequal(circshift((1:5).',-1),[2;3;4;5;1]));
fprintf('Synthetic metrics, periodic lag convention and Parseval PASS.\n');
src=fullfile(root,'results','dpd_sweep','tpf1484cb1_eb1d_4fe1_9d7e_13899ee8f7e5');
mixed=fullfile(root,'diagnostics','pnnn_mixed_loss','tp390d053f_18ea_464b_8c05_db89f2b156eb');
M=load(fullfile(mixed,'tpc6c585a5_81aa_4b4a_8ac0_0ca4c0fbcf81','inference.mat'));
S=load(fullfile(src,'experiment.mat')); B=load(fullfile(src,'models_P0310.mat')); D=load(fullfile(src,'sweep_dense_source.mat'));
N=numel(S.x); id=S.split.identificationIndices; dev=S.split.evaluationIndices;
assert(isequal(M.model.masks,B.bundle.models{3}.masks));
cfg=M.model.featureConfig; st=M.model.normalization;
[f,t,r]=buildPhaseNormDataset(S.x,S.y,cfg.M,cfg.orders,cfg.featMode,cfg); r=r(:);
Z=(f.'-st.muX)./st.sigmaX;
pnn=predictPNNN(M.model.network,Z,st,r); assert(isequal(pnn,M.prediction));
dense=predictPNNN(D.denseSource.denseFit.network,Z,st,r);
fprintf('Recomputed dense NMSE %.12f; mixed %.12f\n',nmseComplexDb(S.y,dense),nmseComplexDb(S.y,pnn));
% Double evaluation of the stored network for readout stationarity only.
net=M.model.network; L=net.Learnables; W=double(extractdata(L.Value{1})); b=double(extractdata(L.Value{2}));
V=double(extractdata(L.Value{3})); bo=double(extractdata(L.Value{4}));
H=1./(1+exp(-(Z*W.'+b.'))); yn=H*V.'+bo.';
manual=conj(r).*complex(yn(:,1)*st.sigmaY(1)+st.muY(1),yn(:,2)*st.sigmaY(2)+st.muY(2));
manualRelative=norm(manual-double(pnn))/norm(double(pnn)); assert(manualRelative<1e-5);
fprintf('Manual double forward relative L2 %.15g\n',manualRelative);
connections=table((1:84).',sum(W~=0,1).','VariableNames',{'Feature','ActiveHiddenConnections'});
neurons=table((1:12).',sum(W~=0,2),sum(V~=0,1).',mean(H<.01|H>.99,1).',std(H,0,1).', ...
    'VariableNames',{'Neuron','ActiveInputWeights','ActiveOutputWeights','Saturation01','ActivationStd'});
writetable(connections,fullfile(out,'connections.csv')); writetable(neurons,fullfile(out,'neurons.csv'));
ez=yn-(t.'-st.muY)./st.sigmaY; w=[1.41775807004113 0.582241929958871]; stationarity=table();
for c=1:2
    keep=find(M.model.masks{3}(c,:)); A=[H(id,keep),ones(numel(id),1)]; e=ez(id,c);
    g=w(c)*(A.'*e)/numel(id); cosines=(A.'*e)./(sqrt(sum(A.^2,1)).'*norm(e));
    stationarity=[stationarity;table(repmat(c,size(A,2),1),[keep(:);0],g,cosines, ...
        'VariableNames',{'Output','NeuronZeroMeansBias','MixedLossGradient','NormalEquationCosine'})]; %#ok<AGROW>
    sv=svd(A./sqrt(sum(A.^2,1)),0); fprintf('Readout output %d columns %d condition %.9g max cosine %.9g gradient norm %.9g\n',c,size(A,2),sv(1)/sv(end),max(abs(cosines)),norm(g));
end
writetable(stationarity,fullfile(out,'readout_stationarity.csv'));
clear f Z H yn ez t manual
% Reconstruct frozen PN-IQ coefficients; retain selected identification basis.
m=B.bundle.models{2}; K=numel(m.selectedColumns); n=numel(m.descriptors);
manager=struct('regPopulation',m.regPopulation); support=(1:n).'; rows=(1:N).';
pg=complex(zeros(N,1)); Uid=zeros(numel(id),K); idPosition=zeros(N,1); idPosition(id)=1:numel(id);
sumU=zeros(1,K); sumU2=zeros(1,K); sumUE=zeros(K,4); sumE=zeros(1,4); sumE2=zeros(1,4); count=0;
metadata=table();
for j=1:K
    col=m.selectedColumns(j); d=m.descriptors(mod(col-1,n)+1);
    future=any(d.envelopeLags<0) || d.carrierLag<0;
    metadata=[metadata;table(j,col>n,d.canonicalGMP,string(d.auxiliaryType),d.carrierLag, ...
        string(mat2str(d.envelopeLags)),string(mat2str(d.envelopePowers)),future, ...
        'VariableNames',{'Feature','IsQ','Canonical','Auxiliary','CarrierLag','EnvelopeLags','Powers','Future'})]; %#ok<AGROW>
end
for first=1:S.cfg.gmp.blockSize:N
    ix=first:min(first+S.cfg.gmp.blockSize-1,N);
    U=buildPNIQFeatures(S.x,rows(ix),r(ix),manager,support,m.descriptors); U=U(:,m.selectedColumns);
    pg(ix)=conj(r(ix)).*complex(U*m.coefficientsI,U*m.coefficientsQ);
    found=idPosition(ix)>0; Uid(idPosition(ix(found)),:)=U(found,:);
    local=~found; er1=r(ix).*(double(pnn(ix))-S.y(ix)); er2=r(ix).*(pg(ix)-S.y(ix));
    E=[real(er1),imag(er1),real(er2),imag(er2)]; E=E(local,:); Ud=U(local,:);
    sumU=sumU+sum(Ud,1); sumU2=sumU2+sum(Ud.^2,1); sumUE=sumUE+Ud.'*E;
    sumE=sumE+sum(E,1); sumE2=sumE2+sum(E.^2,1); count=count+size(E,1);
end
Refs=load(fullfile(src,'linear_sweep.mat'),'linear'); k=find(S.cfg.sweep.parameterGrid==310);
assert(isequal(pg,Refs.linear.predictions.pniqFull(:,k))); clear Refs
fprintf('Frozen neural and PN-IQ predictions exactly match saved references.\n');
R=(sumUE-sumU.'*sumE/count)./sqrt((sumU2.'-sumU.'.^2/count)*(sumE2-sumE.^2/count));
metadata.MixedI=R(:,1); metadata.MixedQ=R(:,2); metadata.PNIQI=R(:,3); metadata.PNIQQ=R(:,4);
writetable(metadata,fullfile(out,'basis_residual_correlations_development.csv'));
eG=r(id).*(pg(id)-S.y(id));
cosG=(Uid.'*[real(eG),imag(eG)])./(sqrt(sum(Uid.^2,1)).'*sqrt(sum([real(eG),imag(eG)].^2,1)));
fprintf('PN-IQ identification normal-equation maximum cosine I/Q %.12g %.12g\n',max(abs(cosG),[],1));
sv=svd(Uid./max(abs(Uid),[],1),0); fprintf('PN-IQ peak-scaled basis condition %.12g min singular %.12g\n',sv(1)/sv(end),sv(end)); clear Uid
disp(B.bundle.metrics); disp(neurons); disp(stationarity);
pred={double(pnn),pg}; labels=["Mixed PNNN","PN-IQ-GMP"]; sets={id,dev,(1:N).'}; domains=["Identification","Development","Full development capture"];
metrics=table(); amplitude=table(); correction=table(); temporal=table(); ac=table(); spectralBands=table();
[~,ampOrder]=sort(abs(S.x)); [~,corrOrder]=sort(abs(S.y-S.x)); edges=round(linspace(0,N,11));
blockEdges=round(linspace(0,N,17)); fs=B.bundle.fs; freq=(-N/2:N/2-1).'*fs/N; psd=zeros(N,2);
for k=1:2
    p=pred{k}; e=p-S.y;
    for j=1:3
        ix=sets{j}; row=extraMetrics(S.x(ix),S.y(ix),p(ix));
        metrics=[metrics;addvars(row,labels(k),domains(j),'Before',1,'NewVariableNames',{'Model','Domain'})]; %#ok<AGROW>
    end
    for j=1:10
        ix=ampOrder(edges(j)+1:edges(j+1)); row=extraMetrics(S.x(ix),S.y(ix),p(ix));
        row.ErrorShare=sum(abs(e(ix)).^2)/sum(abs(e).^2); row.ReferenceEnergyShare=sum(abs(S.y(ix)).^2)/sum(abs(S.y).^2);
        amplitude=[amplitude;addvars(row,labels(k),j,'Before',1,'NewVariableNames',{'Model','Decile'})]; %#ok<AGROW>
        ix=corrOrder(edges(j)+1:edges(j+1)); row=extraMetrics(S.x(ix),S.y(ix),p(ix));
        row.CorrectionMin=min(abs(S.y(ix)-S.x(ix))); row.CorrectionMax=max(abs(S.y(ix)-S.x(ix)));
        correction=[correction;addvars(row,labels(k),j,'Before',1,'NewVariableNames',{'Model','CorrectionDecile'})]; %#ok<AGROW>
    end
    for j=1:16
        ix=blockEdges(j)+1:blockEdges(j+1); row=extraMetrics(S.x(ix),S.y(ix),p(ix));
        temporal=[temporal;addvars(row,labels(k),j,'Before',1,'NewVariableNames',{'Model','Block'})]; %#ok<AGROW>
    end
    ec=e-mean(e);
    for lag=0:64
        value=sum(conj(ec).*circshift(ec,lag))/sum(abs(ec).^2);
        ac=[ac;table(labels(k),lag,real(value),imag(value),abs(value),'VariableNames',{'Model','Lag','Real','Imag','Magnitude'})]; %#ok<AGROW>
    end
    binPower=abs(fftshift(fft(e))).^2/N^2;
    assert(abs(sum(binPower)-mean(abs(e).^2))/mean(abs(e).^2)<1e-12); psd(:,k)=binPower/(fs/N);
    bands={abs(freq)<=48.6e6,abs(freq)>48.6e6&abs(freq)<=100e6,abs(freq)>100e6};
    for j=1:3
        power=sum(binPower(bands{j})); spectralBands=[spectralBands;table(labels(k),j,power,power/sum(binPower), ...
            'VariableNames',{'Model','Band','ErrorPower','Share'})]; %#ok<AGROW>
    end
end
% Correlations with simple lagged features: development rows only, no fitting.
er=r.*(double(pnn)-S.y); eg=r.*(pg-S.y); errors=[real(er(dev)),imag(er(dev)),real(eg(dev)),imag(eg(dev))];
lagCorr=table();
for lag=-2:20
    delayed=circshift(S.x,lag); rotated=r.*delayed;
    F=[real(rotated(dev)),imag(rotated(dev)),abs(delayed(dev)),abs(delayed(dev)).^3,abs(delayed(dev)).^7];
    R=corr(F,errors); kinds=["RotatedI","RotatedQ","Envelope1","Envelope3","Envelope7"];
    lagCorr=[lagCorr;table(repmat(lag,5,1),kinds.',R(:,1),R(:,2),R(:,3),R(:,4), ...
        'VariableNames',{'Lag','Feature','MixedI','MixedQ','PNIQI','PNIQQ'})]; %#ok<AGROW>
end
writetable(lagCorr,fullfile(out,'lag_correlations_development.csv'));
writetable(metrics,fullfile(out,'metrics.csv')); writetable(amplitude,fullfile(out,'amplitude.csv'));
writetable(correction,fullfile(out,'correction_regions.csv')); writetable(temporal,fullfile(out,'temporal.csv'));
writetable(ac,fullfile(out,'autocorrelation.csv')); writetable(spectralBands,fullfile(out,'spectral_bands.csv'));
spec=table(mean(reshape(freq,60,[]),1).',mean(reshape(psd(:,1),60,[]),1).',mean(reshape(psd(:,2),60,[]),1).', ...
    'VariableNames',{'FrequencyHz','MixedErrorPSD','PNIQErrorPSD'}); writetable(spec,fullfile(out,'error_spectrum.csv'));
fprintf('Cross-model centered complex residual correlation magnitude %.9f\n',abs((double(pnn)-S.y-mean(double(pnn)-S.y))'*(pg-S.y-mean(pg-S.y)))/(norm(double(pnn)-S.y-mean(double(pnn)-S.y))*norm(pg-S.y-mean(pg-S.y))));
disp(metrics); disp(spectralBands);
save(fullfile(out,'audit.mat'),'metrics','amplitude','correction','temporal','spectralBands','metadata','neurons','stationarity','manualRelative','cosG','sv','-v7.3');
fig=figure('Visible','off','Position',[100 100 1150 750]); tiledlayout(2,2);
nexttile; plot(1:10,amplitude.NMSE(1:10),'-o',1:10,amplitude.NMSE(11:20),'-o'); title('Input amplitude'); xlabel('Decile'); ylabel('NMSE dB'); legend(labels); grid on;
nexttile; plot(1:10,correction.NMSE(1:10),'-o',1:10,correction.NMSE(11:20),'-o'); title('ILC correction magnitude (not pure nonlinearity)'); xlabel('Decile of |y-x|'); ylabel('NMSE dB'); grid on;
nexttile; plot(1:16,temporal.NMSE(1:16),'-o',1:16,temporal.NMSE(17:32),'-o'); title('Temporal blocks'); xlabel('Consecutive block'); ylabel('NMSE dB'); grid on;
nexttile; plot(spec.FrequencyHz/1e6,10*log10(spec.MixedErrorPSD),spec.FrequencyHz/1e6,10*log10(spec.PNIQErrorPSD)); title('Offline imitation residual spectrum'); xlabel('Frequency MHz'); ylabel('dB native squared units / Hz'); grid on;
sgtitle('Frozen P310 models - development capture only'); exportgraphics(fig,fullfile(out,'residuals.png'),'Resolution',160); close(fig);
fprintf('AUDIT COMPLETE: %s\n',out);
end

function m=extraMetrics(x,y,p)
% Extend common physical metrics with exact magnitude and phase descriptors.
m=errorMetrics(x,y,p); m.AmplitudeRMSE=sqrt(mean((abs(p)-abs(y)).^2));
m.AmplitudeBias=mean(abs(p)-abs(y)); ix=abs(y)>0;
m.AngularRMSEDeg=sqrt(sum(abs(y(ix)).^2.*angle(p(ix).*conj(y(ix))).^2)/sum(abs(y(ix)).^2))*180/pi;
end
