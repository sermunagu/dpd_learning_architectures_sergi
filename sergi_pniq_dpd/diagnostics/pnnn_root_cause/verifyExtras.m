function verifyExtras(referenceOnly)
% VERIFYEXTRAS Read-only prediction references and rotated error components.
% Writes supplemental evidence to a fresh folder; never trains or transmits.
% Optional true completes only reference metrics, without repeating the audit.
if nargin < 1, referenceOnly=false; end
here=fileparts(mfilename('fullpath')); root=fileparts(fileparts(here));
old=path; c=onCleanup(@() path(old)); addpath(genpath(fullfile(root,'toolbox')));
out=tempname(here); mkdir(out); diary(fullfile(out,'verification.log')); dc=onCleanup(@() diary('off'));
folder=fullfile(root,'results','dpd_sweep','tpf1484cb1_eb1d_4fe1_9d7e_13899ee8f7e5');
S=load(fullfile(folder,'experiment.mat')); B=load(fullfile(folder,'models_P0310.mat'));
D=load(fullfile(folder,'sweep_dense_source.mat')); st=D.denseSource.denseFit.normalization;
raw=load(fullfile(fileparts(root),'results','experimentosSergi20261023','experiment20261023T102742_xy.mat'));
dpd=applyDPDModels(B.bundle,raw.x);
L=load(fullfile(folder,'linear_sweep.mat'),'linear'); ix=find(S.cfg.sweep.parameterGrid==310);
refs={L.linear.predictions.complexFull(:,ix),L.linear.predictions.pniqFull(:,ix)};
referenceMetrics=table();
for k=1:2
    fprintf('Linear %d exact=%d maxAbs=%.15g\n',k,isequal(refs{k},dpd(k).yvalmod),max(abs(refs{k}-dpd(k).yvalmod)));
    fprintf('Linear %d relativeL2=%.15g NMSEdelta=%.15g dB\n',k, ...
        norm(refs{k}-dpd(k).yvalmod)/norm(refs{k}),nmseComplexDb(S.y,dpd(k).yvalmod)-nmseComplexDb(S.y,refs{k}));
    a=double(refs{k}(:)); b=double(dpd(k).yvalmod(:));
    maxAbs=max(abs(b-a)); relL2=norm(b-a)/norm(a);
    relMax=maxAbs/max(abs(a)); % Global scale; no division by near-zero samples.
    savedNMSE=nmseComplexDb(S.y,a); reconstructedNMSE=nmseComplexDb(S.y,b);
    deltaDb=abs(reconstructedNMSE-savedNMSE);
    pass=relL2<1e-9 && relMax<1e-9 && deltaDb<1e-8;
    referenceMetrics=[referenceMetrics;table(string(dpd(k).modeltype),isequal(a,b),maxAbs,relL2,relMax, ...
        savedNMSE,reconstructedNMSE,deltaDb,pass,'VariableNames', ...
        {'Model','Exact','MaxAbs','RelativeL2','RelativeMaxGlobal','SavedNMSE','ReconstructedNMSE','AbsNMSEDelta','Pass'})]; %#ok<AGROW>
end
writetable(referenceMetrics,fullfile(out,'reference_metrics.csv')); disp(referenceMetrics);
assert(all(referenceMetrics.Pass),'Reference differences exceed diagnostic error budgets.');
fprintf('Saved sigmaI=%.15g sigmaQ=%.15g weightQ/weightI=%.15g\n',st.sigmaY,st.sigmaY(1)^2/st.sigmaY(2)^2);
if referenceOnly
    checkcode(fullfile(here,'diagnose.m')); checkcode(fullfile(here,'verifyExtras.m'));
    fprintf('REFERENCE CLOSURE COMPLETE: %s\n',out);
    return;
end
clear L refs
[f,~,r]=buildPhaseNormDataset(S.x,S.y,S.cfg.pnnn.M,S.cfg.pnnn.orders,S.cfg.pnnn.featMode,S.cfg.pnnn);
Z=(f.'-st.muX)./st.sigmaX; dense=predictPNNN(D.denseSource.denseFit.network,Z,st,r(:));
p={dpd(1).yvalmod,dpd(2).yvalmod,dpd(3).yvalmod,dense}; labels=["GMP","PN-IQ","P310","dense"]; errors=table();
for k=1:4
    e=r(:).*(double(p{k})-S.y); i=mean(real(e).^2); q=mean(imag(e).^2);
    errors=[errors;table(labels(k),i,q,q/(i+q),(i/st.sigmaY(1)^2+q/st.sigmaY(2)^2)/2, ...
        'VariableNames',{'Model','RadialMSE','QuadratureMSE','QuadratureErrorShare','NormalizedTrainingLossFull'})]; %#ok<AGROW>
end
writetable(errors,fullfile(out,'loss_components.csv')); disp(errors);
M=load(fullfile(fileparts(root),'results','experimentosSergi20261023','experiment20261023T102742_DPD_offline_comparison.mat'));
for k=1:3
    d=double(dpd(k).yvalmod)-double(M.meas_out(k+2).x(:));
    fprintf('Measured pre-CFR signal model %d maxAbs=%.15g relativeL2=%.15g\n',k,max(abs(d)),norm(d)/norm(double(dpd(k).yvalmod)));
end
checkcode(fullfile(here,'diagnose.m')); checkcode(fullfile(here,'verifyExtras.m'));
fprintf('SUPPLEMENT COMPLETE: %s\n',out);
end
