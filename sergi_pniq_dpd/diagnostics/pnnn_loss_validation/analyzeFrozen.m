function analyzeFrozen()
% ANALYZEFROZEN Audit frozen inference and extend same-capture error analysis.
% No inputs. Writes only to a fresh diagnostic folder; never trains.
here=fileparts(mfilename('fullpath')); root=fileparts(fileparts(here));
old=path; pc=onCleanup(@() path(old)); addpath(here,genpath(fullfile(root,'toolbox')));
out=tempname(here); mkdir(out); diary(fullfile(out,'analysis.log')); dc=onCleanup(@() diary('off'));
% Synthetic identities and shape tests before reading experimental arrays.
sx=[0;1;1i;-1;-1i]; sy=[1;2;3;4;5].*exp(1i*(0:4).');
sp=sy+[1;2;3;4;5]*(0.01+0.02i); sm=errorMetrics(sx,sy,sp);
assert(abs(sm.MSE-mean(abs(sp-sy).^2))<1e-15);
assert(abs(sm.NMSE-20*log10(norm(sp-sy)/norm(sy)))<1e-12);
assert(abs(sm.RelativeL2-norm(sp-sy)/norm(sy))<1e-15);
badShape=false;
try
    errorMetrics(sx.',sy,sp);
catch
    badShape=true;
end
assert(badShape);
[sf,st,sr]=buildPhaseNormDataset(sx,sy,13,1:4,'full');
assert(isequal(size(sf),[84 5]) && isequal(size(st),[2 5]));
assert(norm(conj(sr(:)).*complex(st(1,:).',st(2,:).')-sy)<1e-12);
assert(sr(1)==1); fprintf('SYNTHETIC METRICS, SHAPES AND PHASE PASS.\n');
folder=fullfile(root,'results','dpd_sweep','tpf1484cb1_eb1d_4fe1_9d7e_13899ee8f7e5');
prior=fullfile(root,'diagnostics','pnnn_loss_experiment','tp15ee449b_7a1a_4442_a6ae_cdefa2453e8a');
S=load(fullfile(folder,'experiment.mat')); B=load(fullfile(folder,'models_P0310.mat'));
A=load(fullfile(prior,'experimental.mat')); I=load(fullfile(prior,'inference.mat'));
H=load(fullfile(folder,'pnnn_target_0310.mat')); D=load(fullfile(folder,'sweep_dense_source.mat'));
assert(isequal(B.bundle.models{3}.network.Learnables,H.point.model.network.Learnables));
assert(isequal(A.result.masks,H.point.model.masks));
assert(isequal(A.provenance.normalization,H.point.model.normalization,D.denseSource.denseFit.normalization));
assert(isequal(A.provenance.options.TrainingRows,S.split.identificationIndices));
assert(isempty(intersect(S.split.identificationIndices,S.split.evaluationIndices)));
assert(isequal(sort([S.split.identificationIndices;S.split.evaluationIndices]),(1:numel(S.x)).'));
for k=1:height(A.result.network.Learnables)
    a=extractdata(A.result.network.Learnables.Value{k}); b=extractdata(H.point.model.network.Learnables.Value{k});
    assert(isequal(size(a),size(b)) && all(a(~A.result.masks{k})==0) && all(b(~A.result.masks{k})==0));
end
raw=load(fullfile(fileparts(root),'results','experimentosSergi20261023','experiment20261023T102742_xy.mat'));
assert(isequal(double(raw.x(:))-mean(double(raw.x(:))),S.x));
assert(isequal(double(raw.y(:))-mean(double(raw.y(:))),S.y));
cfg=H.point.model.featureConfig; stats=H.point.model.normalization;
[f,~,r]=buildPhaseNormDataset(S.x,zeros(size(S.x)),cfg.M,cfg.orders,cfg.featMode,cfg);
assert(size(f,1)==84); z=(f.'-stats.muX)./stats.sigmaX; clear f
p1=predictPNNN(H.point.model.network,z,stats,r);
p2=predictPNNN(A.result.network,z,stats,r); clear z
assert(isequal(p1,H.point.fullSignalPrediction) && isequal(p2,I.prediction));
% Identical PN-IQ inference operations to the PN-IQ branch of applyDPDModels.
m=B.bundle.models{2}; assert(m.kind=="pniq"); disp(m);
rows=(1:numel(S.x)).'; support=(1:numel(m.regPopulation)).'; manager=struct('regPopulation',m.regPopulation);
p3=complex(zeros(size(S.x))); r=r(:);
for first=1:B.bundle.config.gmp.blockSize:numel(S.x)
    ix=first:min(first+B.bundle.config.gmp.blockSize-1,numel(S.x));
    U=buildPNIQFeatures(S.x,rows(ix),r(ix),manager,support,m.descriptors);
    U=U(:,m.selectedColumns); p3(ix)=conj(r(ix)).*complex(U*m.coefficientsI,U*m.coefficientsQ);
end
L=load(fullfile(folder,'linear_sweep.mat'),'linear'); pi=find(S.cfg.sweep.parameterGrid==310);
assert(isequal(p3,L.linear.predictions.pniqFull(:,pi)));
fprintf('ALL THREE FROZEN PREDICTIONS EXACTLY MATCH SAVED REFERENCES.\n'); clear L
pred={double(p1),double(p2),double(p3)}; labels=["Historical PNNN","Weighted PNNN","PN-IQ-GMP"];
sets={S.split.identificationIndices,S.split.evaluationIndices,S.split.fullSignalIndices};
domains=["Identification","Development complement","Full development capture"];
globalMetrics=table(); bins=table(); phase=table(); crossed=table(); angular=table();
[~,order]=sort(abs(S.x)); edges=round(linspace(0,numel(S.x),11)); dec=zeros(size(S.x));
for b=1:10, dec(order(edges(b)+1:edges(b+1)))=b; end
phaseEdges=linspace(-piValue(),piValue(),13); pb=discretize(angle(S.x),phaseEdges);
for k=1:3
    p=pred{k}; allError=sum(abs(p-S.y).^2); allEnergy=sum(abs(S.y).^2);
    for j=1:3
        ix=sets{j}; row=errorMetrics(S.x(ix),S.y(ix),p(ix));
        globalMetrics=[globalMetrics;addvars(row,labels(k),domains(j),'Before',1,'NewVariableNames',{'Model','Domain'})]; %#ok<AGROW>
    end
    for b=1:10
        ix=find(dec==b); row=errorMetrics(S.x(ix),S.y(ix),p(ix));
        row.ErrorShare=sum(abs(p(ix)-S.y(ix)).^2)/allError;
        row.ReferenceEnergyShare=sum(abs(S.y(ix)).^2)/allEnergy;
        row.ErrorEnergyRatio=row.ErrorShare/row.ReferenceEnergyShare;
        row.MinInputAmplitude=min(abs(S.x(ix))); row.MaxInputAmplitude=max(abs(S.x(ix)));
        bins=[bins;addvars(row,labels(k),b,'Before',1,'NewVariableNames',{'Model','Decile'})]; %#ok<AGROW>
        for h=1:12
            jx=find(dec==b & pb==h); row=errorMetrics(S.x(jx),S.y(jx),p(jx));
            crossed=[crossed;addvars(row,labels(k),b,h,'Before',1,'NewVariableNames',{'Model','Decile','PhaseBin'})]; %#ok<AGROW>
        end
    end
    for h=1:12
        ix=find(pb==h); row=errorMetrics(S.x(ix),S.y(ix),p(ix));
        phase=[phase;addvars(row,labels(k),h,'Before',1,'NewVariableNames',{'Model','PhaseBin'})]; %#ok<AGROW>
    end
    % Target-axis projections and energy-weighted phase error: not RF EVM.
    yt=abs(S.y)>0; ry=conj(S.y(yt))./abs(S.y(yt)); ey=ry.*(p(yt)-S.y(yt));
    phaseError=angle(p(yt).*conj(S.y(yt)));
    phaseRMSE=sqrt(sum(abs(S.y(yt)).^2.*phaseError.^2)/sum(abs(S.y(yt)).^2))*180/piValue();
    angular=[angular;table(labels(k),mean(real(ey).^2),mean(imag(ey).^2),phaseRMSE, ...
        'VariableNames',{'Model','TargetRadialMSE','TargetTangentialMSE','EnergyWeightedPhaseRMSEDeg'})]; %#ok<AGROW>
end
writetable(globalMetrics,fullfile(out,'metrics.csv')); writetable(bins,fullfile(out,'amplitude.csv'));
writetable(phase,fullfile(out,'phase.csv')); writetable(crossed,fullfile(out,'amplitude_phase.csv'));
writetable(angular,fullfile(out,'target_axis.csv'));
gainI=globalMetrics.MSEI(3)-globalMetrics.MSEI(6); penaltyQ=globalMetrics.MSEQ(6)-globalMetrics.MSEQ(3);
fprintf('I reduction %.15g; Q penalty %.15g; fraction offset %.9f; net %.15g\n',gainI,penaltyQ,penaltyQ/gainI,gainI-penaltyQ);
disp(globalMetrics); disp(angular);
fig=figure('Visible','off','Position',[100 100 1100 750]); tiledlayout(2,2);
nexttile; hold on; for k=1:3, semilogy(1:10,bins.MSE((k-1)*10+(1:10)),'-o'); end
set(gca,'YScale','log'); title('Absolute complex MSE'); ylabel('Native squared units'); xlabel('Input amplitude decile'); grid on; legend(labels,'Location','northwest');
nexttile; hold on; for k=1:3, plot(1:10,bins.NMSE((k-1)*10+(1:10)),'-o'); end
title('Error / reference energy within decile'); ylabel('NMSE (dB)'); xlabel('Input amplitude decile'); grid on;
nexttile; hold on; for k=1:3, plot(1:10,100*bins.ErrorShare((k-1)*10+(1:10)),'-o'); end
plot(1:10,100*bins.ReferenceEnergyShare(1:10),'k--'); title('Error concentration and target energy'); ylabel('Share (%)'); xlabel('Input amplitude decile'); grid on;
nexttile; hold on; plot(1:10,100*(bins.MSEI(11:20)./bins.MSEI(1:10)-1),'-o');
plot(1:10,100*(bins.MSEQ(11:20)./bins.MSEQ(1:10)-1),'-o'); yline(0,'k--');
title('Weighted vs historical, rotated components'); ylabel('MSE change (%)'); xlabel('Input amplitude decile'); legend('I','Q'); grid on;
sgtitle('October development capture only - no independent test');
exportgraphics(fig,fullfile(out,'amplitude.png'),'Resolution',160); close(fig);
save(fullfile(out,'analysis.mat'),'globalMetrics','bins','phase','crossed','angular','phaseEdges','labels','-v7.3');
fprintf('NO TRAINING. SAME-CAPTURE ANALYSIS COMPLETE: %s\n',out);
end

function value=piValue()
% Return pi without collision with the stored P310 index variable.
value=acos(-1);
end
