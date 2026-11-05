function runMixedLoss()
% RUNMIXEDLOSS Validate and execute exactly one alpha=0.5 real P310 fit.
% No inputs; writes a unique folder here. Historical sources are read-only.
here=fileparts(mfilename('fullpath')); root=fileparts(fileparts(here));
priorCode=fullfile(root,'diagnostics','pnnn_loss_experiment');
old=path; pc=onCleanup(@() path(old)); addpath(here,priorCode,genpath(fullfile(root,'toolbox')));
assert(isempty(dir(fullfile(here,'*','training_started.mat'))),'A real fit was already started.');
assert(isempty(dir(fullfile(here,'*','experimental.mat'))),'Analyze the existing fit instead.');
out=tempname(here); mkdir(out); diary(fullfile(out,'execution.log')); dc=onCleanup(@() diary('off'));
previous=fullfile(priorCode,'tp15ee449b_7a1a_4442_a6ae_cdefa2453e8a');
P=load(fullfile(previous,'protocol.mat')); alpha=0.5;
physicalWeights=P.provenance.weights; weights=1-alpha+alpha*physicalWeights;
assert(max(abs(physicalWeights-[1.8355161401 0.1644838599]))<5e-11);
assert(abs(mean(weights)-1)<1e-14);
% Test the same helper used inside modelLoss; no network training here.
rng(701,'twister'); z=randn(2,7); t=randn(2,7); n=size(z,2);
[loss,g]=dlfeval(@lossGradient,dlarray(z,'CB'),dlarray(t,'CB'),weights);
[l0,g0]=dlfeval(@lossGradient,dlarray(z,'CB'),dlarray(t,'CB'),[1 1]);
[l1,g1]=dlfeval(@lossGradient,dlarray(z,'CB'),dlarray(t,'CB'),physicalWeights);
analytic=weights(:).*(z-t)/n;
checks.lossIdentity=abs(extractdata(loss)-(0.5*extractdata(l0)+0.5*extractdata(l1)));
checks.gradientIdentity=max(abs(extractdata(g)-0.5*(extractdata(g0)+extractdata(g1))),[],'all');
checks.analyticGradient=max(abs(extractdata(g)-analytic),[],'all');
fd=zeros(size(z)); h=1e-6;
for k=1:numel(z)
    plus=z; minus=z; plus(k)=plus(k)+h; minus(k)=minus(k)-h;
    fd(k)=(mean(weights(:).*(plus-t).^2,'all')-mean(weights(:).*(minus-t).^2,'all'))/(2*h);
end
checks.finiteDifference=max(abs(fd-analytic),[],'all');
assert(checks.lossIdentity<1e-12 && checks.gradientIdentity<1e-12 && checks.analyticGradient<1e-12);
assert(checks.finiteDifference<1e-8);
[~,gs]=dlfeval(@lossGradient,dlarray(single(z),'CB'),dlarray(single(t),'CB'),weights);
checks.singleGradient=max(abs(double(extractdata(gs))-double(single(weights(:)).*(single(z)-single(t))/n)),[],'all');
assert(checks.singleGradient<1e-6);
fprintf('SYNTHETIC LOSS/GRADIENT CHECKS PASS.\n'); disp(checks);
folder=P.provenance.sourceFolder;
S=load(fullfile(folder,'experiment.mat')); D=load(fullfile(folder,'sweep_dense_source.mat'));
B=load(fullfile(folder,'pnnn_target_0310.mat')); st=D.denseSource.denseFit.normalization;
assert(isequal(st,P.provenance.normalization,B.point.model.normalization));
assert(isequal(physicalWeights,2*st.sigmaY.^2/sum(st.sigmaY.^2)));
raw=load(fullfile(fileparts(root),'results','experimentosSergi20261023','experiment20261023T102742_xy.mat'));
assert(isequal(double(raw.x(:))-mean(double(raw.x(:))),S.x));
assert(isequal(double(raw.y(:))-mean(double(raw.y(:))),S.y)); clear raw
[f,t,~]=buildPhaseNormDataset(S.x,S.y,S.cfg.pnnn.M,S.cfg.pnnn.orders,S.cfg.pnnn.featMode,S.cfg.pnnn);
f=f.'; t=t.'; id=S.split.identificationIndices;
assert(size(f,2)==84 && D.denseSource.fineTuneEpochs==164);
sx=std(f(id,:),0,1); sx(sx==0)=1;
assert(isequal(mean(f(id,:),1),st.muX) && isequal(sx,st.sigmaX));
assert(isequal(mean(t(id,:),1),st.muY) && isequal(std(t(id,:),0,1),st.sigmaY));
options=P.provenance.options; options.LossWeights=weights;
assert(options.FineTuneEpochs==164 && ~options.Config.pruning.useAcceleration);
assert(isequal(options.TrainingRows,id) && options.Mode=="fixed-epochs");
assert(isequal(rmfield(options,'LossWeights'),rmfield(P.provenance.options,'LossWeights')));
zero=options; zero.FineTuneEpochs=0;
initial=pruneAndFineTunePNNN(D.denseSource.denseFit,f,t,zero);
assert(isequal(initial.network.Learnables,P.initial.network.Learnables));
assert(isequal(initial.masks,P.initial.masks,B.point.model.masks));
rng(options.NNSeed+options.Config.pruning.fineTuneSeedOffset,'twister');
for epoch=1:164
    assert(isequal(uint32(randperm(numel(id))).',P.orders(:,epoch)));
end
assert(isequal(rng,P.expectedRng)); expectedRng=P.expectedRng;
provenance=P.provenance; provenance.options=options; provenance.weights=weights;
provenance.physicalWeights=physicalWeights; provenance.alpha=alpha; provenance.previousProtocol=fullfile(previous,'protocol.mat');
provenance.matlab=version; provenance.computer=computer; provenance.threads=maxNumCompThreads;
provenance.started=char(datetime('now')); provenance.trainingHelper=which('lossPrunePNNN');
save(fullfile(out,'protocol.mat'),'provenance','initial','expectedRng','checks','-v7.3');
fprintf('PRECHECKS PASS. Weights %.15g %.15g. One real fit starts now.\n',weights);
save(fullfile(out,'training_started.mat'),'options');
tic; result=lossPrunePNNN(D.denseSource.denseFit,f,t,options); seconds=toc; finalRng=rng;
save(fullfile(out,'experimental.mat'),'result','seconds','finalRng','provenance','-v7.3');
assert(isequal(result.masks,initial.masks) && isequal(finalRng,expectedRng));
assert(result.bestEpoch==164 && result.counts.activeWeightParams==296 && result.counts.activeBiasParams==14);
fprintf('FIT SAVED %.9f seconds. Exact masks and RNG; 164 epochs.\n%s\n',seconds,out);
end

function [loss,g]=lossGradient(z,t,w)
% Evaluate and differentiate the unchanged diagnostic loss helper.
loss=weightedLoss(z,t,w); g=dlgradient(loss,z);
end
